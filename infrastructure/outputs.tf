#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Resource group ID."
  value       = azurerm_resource_group.this.id
}

#--------------------------------------------------------------
# Network (multiple VNets)
#--------------------------------------------------------------

output "vnet_ids" {
  description = "Map of VNet keys to their IDs."
  value       = { for k, v in module.vnet : k => v.vnet_id }
}

output "vnet_names" {
  description = "Map of VNet keys to their names."
  value       = { for k, v in module.vnet : k => v.vnet_name }
}

output "subnet_ids" {
  description = "Map of VNet keys to their subnet ID maps."
  value       = { for k, v in module.vnet : k => v.subnet_ids }
}

#--------------------------------------------------------------
# Storage (multiple accounts)
#--------------------------------------------------------------

output "storage_account_names" {
  description = "Map of storage account keys to their names."
  value       = { for k, v in module.storage : k => v.storage_account_name }
}

output "storage_account_ids" {
  description = "Map of storage account keys to their IDs."
  value       = { for k, v in module.storage : k => v.storage_account_id }
}

output "storage_blob_endpoints" {
  description = "Map of storage account keys to their blob endpoints."
  value       = { for k, v in module.storage : k => v.primary_blob_endpoint }
}

#--------------------------------------------------------------
# Virtual Machines (multiple VMs)
#--------------------------------------------------------------

output "vm_names" {
  description = "Map of VM keys to their names."
  value       = { for k, v in module.vm : k => v.vm_name }
}

output "vm_ids" {
  description = "Map of VM keys to their IDs."
  value       = { for k, v in module.vm : k => v.vm_id }
}

output "vm_availability_zones" {
  description = "Map of VM keys to their availability zones."
  value       = { for k, v in module.vm : k => v.vm_availability_zone }
}

#--------------------------------------------------------------
# Security
#--------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

#--------------------------------------------------------------
# Load Balancer
#--------------------------------------------------------------

output "load_balancer_id" {
  description = "Load Balancer ID."
  value       = azurerm_lb.this.id
}

output "load_balancer_backend_pool_id" {
  description = "LB backend pool ID (for adding more VMs)."
  value       = azurerm_lb_backend_address_pool.this.id
}

#--------------------------------------------------------------
# Backup
#--------------------------------------------------------------

output "recovery_vault_name" {
  description = "Recovery Services Vault name."
  value       = azurerm_recovery_services_vault.this.name
}
