terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "devops-secure-infra-rg"
    storage_account_name = "devopsterraformstateacct"
    container_name       = "tfstatefiles"
    key                  = "terraform.state"        # State file name stored in blob storage
  }
}

provider "azurerm" {
  features {}
}

# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.environment}-secure-infra"
  location = var.location
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.network_segment[var.environment]["address_space"]
}

# Create Subnets
resource "azurerm_subnet" "backend_subnet" {
  name                 = "backend-subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.network_segment[var.environment]["backend_subnet_prefixes"]
}

# Create a subnet in the Virtual Network for creating Azure Bastion
# This subnet is required for Azure Bastion to work properly
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.network_segment[var.environment]["bastion_subnet_prefixes"]
}

# Create Network Security Group and rules to control the traffic
# to and from the Virtual Machines in the Backend Pool
resource "azurerm_network_security_group" "nsg_backend" {
  name                = "backend-nsg-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "ssh"
    priority                   = 1022
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefixes = var.network_segment[var.environment]["source_address_prefixes"]
  }

  security_rule {
    name                       = "web"
    priority                   = 1080
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefixes = var.network_segment[var.environment]["source_address_prefixes"]
  }
}


# Associate the Network Security Group to the subnet to allow the
# Network Security Group to control the traffic to and from the subnet
resource "azurerm_subnet_network_security_group_association" "nsg_backend_association" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg_backend.id
}

# Create Public IP Address for the Load Balancer
resource "azurerm_public_ip" "public_ip" {
  count               = 2
  name                = "${var.environment}-load-balancer-public-ip-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Virtual Machine (VM)
resource "azurerm_network_interface" "nic" {
  name                = "${var.environment}-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.environment}-ip-config"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

# Create Azure Bastion for accessing the Virtual Machines
# The Bastion Host will be used to access the Virtual
# Machines in the Backend Pool of the Load Balancer
resource "azurerm_bastion_host" "example" {
  name                = "${var.environment}-vm-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  ip_configuration {
    name                 = "${var.environment}-ipconfig"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.public_ip[1].id
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.vm_name}-${var.environment}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = var.vm_image["publisher"]
    offer     = var.vm_image["offer"]
    sku       = var.vm_image["sku"]
    version   = var.vm_image["version"]
  }

  storage_os_disk {
    name              = "os-disk-${var.environment}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.environment}-web-server"
    admin_username = "azureuser"
    admin_password = var.vm_admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Enable virtual machine extension and install Nginx
# The script will update the package list, install Nginx,
# and create a simple HTML page
resource "azurerm_virtual_machine_extension" "extension" {
  name                 = "Nginx"
  virtual_machine_id   = azurerm_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
{
 "commandToExecute": "sudo apt-get update && sudo apt-get install nginx -y && echo \"Hello World from $(hostname)\" > /var/www/html/index.html && sudo systemctl restart nginx"
}
SETTINGS

}

# Create Azure Load Balancer
resource "azurerm_lb" "lb" {
  name                = "${var.environment}-app-load-balancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.environment}-frontend-ip-conf"
    public_ip_address_id = azurerm_public_ip.public_ip[0].id
  }
}

# Create a Load Balancer Probe to check the health of the
# Virtual Machines in the Backend Pool
resource "azurerm_lb_probe" "lbprobe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "${var.environment}-test-probe"
  port            = 80
}

# Create Backend Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "${var.environment}-backend-pool"
}

# Associate Network Interface to the Backend Pool of the Load Balancer
# The Network Interface will be used to route traffic to the Virtual
# Machines in the Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "backend_address_pool_association" {
  network_interface_id    = azurerm_network_interface.nic.id
  ip_configuration_name   = "${var.environment}-ip-config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# Create a Load Balancer Rule to define how traffic will be
# distributed to the Virtual Machines in the Backend Pool
resource "azurerm_lb_rule" "lbrule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "${var.environment}-test-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  disable_outbound_snat          = true
  frontend_ip_configuration_name = "${var.environment}-frontend-ip-conf"
  probe_id                       = azurerm_lb_probe.lbprobe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
}

resource "azurerm_lb_outbound_rule" "lb_outbound" {
  name                    = "${var.environment}-test-outbound"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id

  frontend_ip_configuration {
    name = "${var.environment}-frontend-ip-conf"
  }
}
