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
  address_space       = ["10.${lookup({"DEV": "0", "STG": "1", "PROD": "2"}, var.environment)}.0.0/16"]
}

# Create Subnets
resource "azurerm_subnet" "backend_subnet" {
  name                 = "backend-subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.${lookup({"DEV": "0", "STG": "1", "PROD": "2"}, var.environment)}.1.0/24"]
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet-${var.environment}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.${lookup({"DEV": "0", "STG": "1", "PROD": "2"}, var.environment)}.2.0/24"]
}

# Create Network Security Groups
resource "azurerm_network_security_group" "nsg_public" {
  name                = "public-nsg-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny_all"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_backend" {
  name                = "backend-nsg-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule {
    name                       = "allow_internal_traffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = ["10.${lookup({"DEV": "0", "STG": "1", "PROD": "2"}, var.environment)}.0.0/16"]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny_all"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create Public IP Address for the Load Balancer
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.environment}-load-balancer-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Create Azure Load Balancer
resource "azurerm_lb" "lb" {
  name                = "${var.environment}-app-load-balancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.environment}-frontend-ip-conf"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

# Create Backend Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "${var.environment}-backend-pool"
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
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "vm-${var.environment}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = var.vm_size

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
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

# Provision File with "Hello World" Content
resource "null_resource" "install_httpd" {
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
      "echo '<html><body><h1>Hello World</h1></body></html>' | sudo tee /var/www/html/index.html",
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2"
    ]

    connection {
      type     = "ssh"
      host     = azurerm_public_ip.public_ip.ip_address
      user     = "azureuser"
      password = var.vm_admin_password
    }
  }
}
