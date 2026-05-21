#--------------------------------------------------------------
# Locals
#--------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.location}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
    Owner       = var.owner
    Region      = var.location
  }
}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

#--------------------------------------------------------------
# Random suffix for globally unique names
#--------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

#--------------------------------------------------------------
# Data Sources
#--------------------------------------------------------------

data "azurerm_client_config" "current" {}

#--------------------------------------------------------------
# Module: Virtual Networks (scalable - supports multiple)
#--------------------------------------------------------------

module "vnet" {
  source   = "git::https://github.com/rsat564/tfmodules.git//vnet?ref=v1.0.0"
  for_each = var.vnets

  name                = "vnet-${each.key}-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  nsg_rules           = each.value.nsg_rules
  tags                = merge(local.common_tags, { VNet = each.key })
}

#--------------------------------------------------------------
# Key Vault (shared security resource)
#--------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  name                          = "kv-${var.project_name}-${var.environment}-${random_string.suffix.result}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 30
  public_network_access_enabled = var.environment == "prod" ? false : true

  network_acls {
    default_action = var.environment == "prod" ? "Deny" : "Allow"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = flatten([
      for vnet_key, vnet in module.vnet : [
        for subnet_key, subnet_id in vnet.subnet_ids : subnet_id
      ]
    ])
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# Protect Key Vault from accidental deletion
resource "azurerm_management_lock" "kv_lock" {
  name       = "lock-${azurerm_key_vault.this.name}"
  scope      = azurerm_key_vault.this.id
  lock_level = "CanNotDelete"
  notes      = "Key Vault contains encryption keys - cannot be deleted"
}

resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

#--------------------------------------------------------------
# Disk Encryption Set (shared for all VMs)
#--------------------------------------------------------------

resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "key-disk-encryption-${var.environment}"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "wrapKey", "unwrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P29D"
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

resource "azurerm_disk_encryption_set" "this" {
  name                = "des-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption.id

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "des_kv_access" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.this.identity[0].principal_id
}

#--------------------------------------------------------------
# Storage Encryption Key
#--------------------------------------------------------------

resource "azurerm_key_vault_key" "storage_encryption" {
  name         = "key-storage-encryption-${var.environment}"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "wrapKey", "unwrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P29D"
  }

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

#--------------------------------------------------------------
# Module: Storage Accounts (scalable - supports multiple)
#--------------------------------------------------------------

module "storage" {
  source   = "git::https://github.com/rsat564/tfmodules.git//storage?ref=v1.0.0"
  for_each = var.storage_accounts

  name                = "st${var.project_name}${each.key}${var.environment}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  account_tier        = each.value.account_tier
  replication_type    = each.value.replication_type
  containers          = each.value.containers
  allowed_subnet_ids = [
    for ref in each.value.allowed_subnet_ids_keys :
    module.vnet[ref.vnet_key].subnet_ids[ref.subnet_key]
  ]
  public_network_access = var.environment != "prod"

  soft_delete_retention_days           = var.environment == "prod" ? 30 : 7
  container_soft_delete_retention_days = var.environment == "prod" ? 30 : 7

  lifecycle_rules             = each.value.lifecycle_rules
  encryption_key_vault_key_id = azurerm_key_vault_key.storage_encryption.id

  tags = merge(local.common_tags, { StorageAccount = each.key })
}

# Grant storage accounts access to Key Vault for CMK encryption
resource "azurerm_role_assignment" "storage_kv_access" {
  for_each = module.storage

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = each.value.identity_principal_id
}

#--------------------------------------------------------------
# Recovery Services Vault (shared for all VM backups)
#--------------------------------------------------------------

resource "azurerm_recovery_services_vault" "this" {
  name                = "rsv-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  storage_mode_type   = var.environment == "prod" ? "ZoneRedundant" : "LocallyRedundant"

  cross_region_restore_enabled = var.environment == "prod" ? true : false
  immutability                 = var.environment == "prod" ? "Unlocked" : null

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_backup_policy_vm" "this" {
  name                = "bkpol-vm-${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = var.environment == "prod" ? 30 : 7
  }

  retention_weekly {
    count    = var.environment == "prod" ? 12 : 4
    weekdays = ["Sunday"]
  }
}

#--------------------------------------------------------------
# Module: Virtual Machines (scalable - supports multiple)
#--------------------------------------------------------------

module "vm" {
  source   = "git::https://github.com/rsat564/tfmodules.git//vm?ref=v1.0.0"
  for_each = var.vms

  name                          = "vm-${each.key}-${local.name_prefix}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  subnet_id                     = module.vnet[each.value.vnet_key].subnet_ids[each.value.subnet_key]
  vm_size                       = each.value.vm_size
  admin_username                = each.value.admin_username
  os_disk_size_gb               = each.value.os_disk_size_gb
  os_disk_type                  = each.value.os_disk_type
  availability_zone             = each.value.availability_zone
  enable_accelerated_networking = each.value.enable_accelerated_networking
  data_disks                    = each.value.data_disks
  disk_encryption_set_id        = azurerm_disk_encryption_set.this.id

  # Backup
  enable_backup       = each.value.enable_backup
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  backup_policy_id    = azurerm_backup_policy_vm.this.id

  # Monitoring
  enable_monitoring = each.value.enable_monitoring

  tags = merge(local.common_tags, { VM = each.key })

  depends_on = [azurerm_role_assignment.des_kv_access]
}

# Store SSH keys in Key Vault (one per VM)
resource "azurerm_key_vault_secret" "vm_ssh_key" {
  for_each = module.vm

  name         = "vm-ssh-key-${each.key}-${var.environment}"
  value        = each.value.ssh_private_key
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

#--------------------------------------------------------------
# Load Balancer (HA - associates all VMs)
#--------------------------------------------------------------

resource "azurerm_lb" "this" {
  name                = "lb-${local.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal-frontend"
    subnet_id                     = module.vnet[var.lb_vnet_key].subnet_ids[var.lb_subnet_key]
    private_ip_address_allocation = "Dynamic"
    zones                         = ["1", "2", "3"]
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "this" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "backend-pool-${var.environment}"
}

resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  for_each = module.vm

  network_interface_id    = each.value.nic_id
  ip_configuration_name  = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "http-probe"
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "https-probe"
  protocol        = "Tcp"
  port            = 443
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "https-rule"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "internal-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.https.id
  disable_outbound_snat          = true
}
