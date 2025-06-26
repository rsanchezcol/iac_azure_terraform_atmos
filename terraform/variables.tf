# variables.tf

variable "environment" {
  description = "The environment in which resources will be deployed (DEV, STG, PROD)"
  type        = string
  validation {
    condition     = can(regex("^(DEV|STG|PROD)$", var.environment))
    error_message = "Invalid environment! Must be one of: DEV, STG, PROD."
  }
}

variable "vm_admin_password" {
  description = "The admin password for the VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Size of the virtual machine"
  default     = "Standard_DS1_v2"
}

variable "location" {
  description = "Azure region where resources will be provisioned"
  default     = "East US"
}
