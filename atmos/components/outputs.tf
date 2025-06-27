# Output the Resource Group Name
output "resource_group_name" {
  description = "The name of the created Resource Group"
  value       = azurerm_resource_group.rg.name
}

# Output the Virtual Network Name
output "virtual_network_name" {
  description = "The name of the created Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

# Output the Backend Subnet Name
output "backend_subnet_name" {
  description = "The name of the backend subnet"
  value       = azurerm_subnet.backend_subnet.name
}

# Output the Name of the Load Balancer
output "load_balancer_name" {
  description = "The name of the Load Balancer"
  value       = azurerm_lb.lb.name
}

output "nsg_backend_name" {
  description = "The name of the Backend Network Security Group"
  value       = azurerm_network_security_group.nsg_backend.name
}

# Output the Virtual Machine Name
output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_virtual_machine.vm.name
}

# Output the Network Interface Name
output "network_interface_name" {
  description = "The name of the Network Interface attached to the VM"
  value       = azurerm_network_interface.nic.name
}
