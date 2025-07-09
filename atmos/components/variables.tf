variable "environment" {
  description = "The environment in which resources will be deployed (DEV, STG, PROD)"
  type        = string
  validation {
    condition     = can(regex("^(DEV|STG|PROD)$", var.environment))
    error_message = "Invalid environment! Must be one of: DEV, STG, PROD."
  }
}

variable "location" {
  description = "Azure region where resources will be provisioned"
  default     = "East US"
}

# VM name
variable "vm_name" {
  default     = "vm-webserver1"
  description = "Name of the virtual machine"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  default     = "Standard_D2als_v6"
}

variable "vm_admin_password" {
  description = "The admin password for the VM"
  type        = string
  sensitive   = true
}

# VM image properties
variable "vm_image" {
  description = "VM image properties"
  type        = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# OS disk properties
variable "os_disk" {
  description = "OS disk properties"
  type        = object({
    caching           = string
    create_option     = string
    managed_disk_type = string
  })
  default = {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
}

# Define network segmentation based on environments
variable "network_segment" {
  description = "Network segmentation by environment"
  type        = map(map(any))
  default = {
    DEV = {
      address_space           = ["10.0.0.0/16"]
      backend_subnet_prefixes = ["10.0.1.0/24"]
      bastion_subnet_prefixes = ["10.0.2.0/24"]
      source_address_prefixes = ["10.0.0.0/16"]
    }
    STG = {
      address_space           = ["10.1.0.0/16"]
      backend_subnet_prefixes = ["10.1.1.0/24"]
      bastion_subnet_prefixes = ["10.1.2.0/24"]
      source_address_prefixes = ["10.1.0.0/16"]
    }
    PROD = {
      address_space           = ["10.2.0.0/16"]
      backend_subnet_prefixes = ["10.2.1.0/24"]
      bastion_subnet_prefixes = ["10.2.2.0/24"]
      source_address_prefixes = ["10.2.0.0/16"]
    }
  }
}
