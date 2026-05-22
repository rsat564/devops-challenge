#--------------------------------------------------------------
# Common Variables
#--------------------------------------------------------------

variable "environment" {
  description = "Deployment environment (dev, test, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for resource deployment."
  type        = string

  validation {
    condition     = contains(["eastus", "eastus2", "westus2", "westeurope", "northeurope", "centralus"], var.location)
    error_message = "Location must be an approved Azure region."
  }
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "cloudops"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,12}$", var.project_name))
    error_message = "Project name: 3-13 lowercase alphanumeric, starts with letter."
  }
}

variable "cost_center" {
  description = "Cost center for billing."
  type        = string
  default     = "engineering"
}

variable "owner" {
  description = "Team responsible for these resources."
  type        = string
  default     = "platform-team"
}

variable "lb_vnet_key" {
  description = "VNet key for the Load Balancer frontend. Must be a key in var.vnets."
  type        = string
  default     = "main"
}

variable "lb_subnet_key" {
  description = "Subnet key within the LB VNet for the frontend IP."
  type        = string
  default     = "snet-app"
}

#--------------------------------------------------------------
# Network Variables
#--------------------------------------------------------------

variable "vnets" {
  description = "Map of VNet configurations. Each key creates a separate VNet."
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefixes  = list(string)
      service_endpoints = optional(list(string), [])
      delegation = optional(object({
        name = string
        service_delegation = object({
          name    = string
          actions = optional(list(string), [])
        })
      }), null)
      private_endpoint_network_policies_enabled     = optional(bool, true)
      private_link_service_network_policies_enabled = optional(bool, true)
    }))
    nsg_rules = optional(map(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = optional(string, "*")
      destination_port_range     = optional(string, "*")
      source_address_prefix      = optional(string, "*")
      destination_address_prefix = optional(string, "*")
    }))), {})
  }))
}

#--------------------------------------------------------------
# VM Variables
#--------------------------------------------------------------

variable "vms" {
  description = "Map of VM configurations. Each key creates a separate VM."
  type = map(object({
    vnet_key                      = string
    subnet_key                    = string
    vm_size                       = optional(string, "Standard_D2s_v3")
    admin_username                = optional(string, "azureadmin")
    os_disk_size_gb               = optional(number, 30)
    os_disk_type                  = optional(string, "Premium_LRS")
    availability_zone             = optional(string, "1")
    enable_accelerated_networking = optional(bool, true)
    enable_backup                 = optional(bool, true)
    enable_monitoring             = optional(bool, true)
    data_disks = optional(map(object({
      disk_size_gb         = number
      storage_account_type = string
      lun                  = number
      caching              = optional(string, "ReadOnly")
    })), {})
  }))
}

#--------------------------------------------------------------
# Storage Variables
#--------------------------------------------------------------

variable "enable_management_lock" {
  description = "Create a CanNotDelete management lock on the Key Vault. Requires Microsoft.Authorization/locks/write (Owner or User Access Administrator). Set to false when the deployer SP only has Contributor."
  type        = bool
  default     = true
}

variable "storage_accounts" {
  description = "Map of Storage Account configurations. Each key creates a separate Storage Account."
  type = map(object({
    account_tier     = optional(string, "Standard")
    replication_type = optional(string, "ZRS")
    containers = optional(map(object({
      access_type = optional(string, "private")
    })), {})
    allowed_subnet_ids_keys = optional(list(object({
      vnet_key   = string
      subnet_key = string
    })), [])
    lifecycle_rules = optional(list(object({
      name                       = string
      enabled                    = optional(bool, true)
      prefix_match               = optional(list(string), [])
      blob_types                 = optional(list(string), ["blockBlob"])
      tier_to_cool_after_days    = optional(number, null)
      tier_to_archive_after_days = optional(number, null)
      delete_after_days          = optional(number, null)
      snapshot_delete_after_days = optional(number, null)
      version_delete_after_days  = optional(number, null)
    })), [])
  }))
}
