# =============================================================
# PROD Environment - East US
# =============================================================

environment  = "prod"
location     = "eastus"
project_name = "cloudops"
cost_center  = "engineering"
owner        = "platform-team"

# Load Balancer placement
lb_vnet_key   = "app"
lb_subnet_key = "snet-web"

# =============================================================
# VNets (prod has app VNet + separate data VNet)
# =============================================================

vnets = {
  "app" = {
    address_space = ["10.30.0.0/17"]
    subnets = {
      "snet-web" = {
        address_prefixes  = ["10.30.1.0/24"]
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
      }
      "snet-api" = {
        address_prefixes  = ["10.30.2.0/24"]
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      }
      "snet-mgmt" = {
        address_prefixes  = ["10.30.3.0/24"]
        service_endpoints = ["Microsoft.KeyVault"]
      }
    }
    nsg_rules = {
      "snet-web" = [
        {
          name                       = "AllowHTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      "snet-api" = [
        {
          name                       = "AllowHTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "443"
          source_address_prefix      = "10.30.1.0/24"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      "snet-mgmt" = [
        {
          name                       = "AllowSSH"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "22"
          source_address_prefix      = "10.30.3.0/24"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
    }
  }

  "data" = {
    address_space = ["10.30.128.0/17"]
    subnets = {
      "snet-db" = {
        address_prefixes  = ["10.30.128.0/24"]
        service_endpoints = ["Microsoft.Sql"]
      }
      "snet-private-endpoints" = {
        address_prefixes                          = ["10.30.129.0/24"]
        service_endpoints                         = []
        private_endpoint_network_policies_enabled = false
      }
    }
    nsg_rules = {
      "snet-db" = [
        {
          name                       = "AllowSQLFromApp"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "1433"
          source_address_prefix      = "10.30.0.0/17"
          destination_address_prefix = "VirtualNetwork"
        },
        {
          name                       = "DenyAllInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      "snet-private-endpoints" = [
        {
          name                       = "DenyAllInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
    }
  }
}

# =============================================================
# VMs (prod: multi-zone deployment)
# =============================================================

vms = {
  "web-1" = {
    vnet_key                      = "app"
    subnet_key                    = "snet-web"
    vm_size                       = "Standard_D4s_v4"
    os_disk_size_gb               = 64
    os_disk_type                  = "Premium_ZRS"
    availability_zone             = "1"
    enable_accelerated_networking = true
    data_disks = {
      "data" = {
        disk_size_gb         = 256
        storage_account_type = "Premium_ZRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
    }
  }
  "web-2" = {
    vnet_key                      = "app"
    subnet_key                    = "snet-web"
    vm_size                       = "Standard_D4s_v4"
    os_disk_size_gb               = 64
    os_disk_type                  = "Premium_ZRS"
    availability_zone             = "2"
    enable_accelerated_networking = true
    data_disks = {
      "data" = {
        disk_size_gb         = 256
        storage_account_type = "Premium_ZRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
    }
  }
  "api-1" = {
    vnet_key                      = "app"
    subnet_key                    = "snet-api"
    vm_size                       = "Standard_D4s_v4"
    os_disk_size_gb               = 64
    os_disk_type                  = "Premium_ZRS"
    availability_zone             = "3"
    enable_accelerated_networking = true
    data_disks = {
      "data" = {
        disk_size_gb         = 128
        storage_account_type = "Premium_ZRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
      "logs" = {
        disk_size_gb         = 128
        storage_account_type = "Premium_ZRS"
        lun                  = 1
        caching              = "None"
      }
    }
  }
}

# =============================================================
# Storage Accounts (prod: separate app + backup accounts)
# =============================================================

storage_accounts = {
  "app" = {
    account_tier     = "Standard"
    replication_type = "RAGZRS"
    containers = {
      "data"      = { access_type = "private" }
      "logs"      = { access_type = "private" }
      "artifacts" = { access_type = "private" }
    }
    allowed_subnet_ids_keys = [
      { vnet_key = "app", subnet_key = "snet-web" },
      { vnet_key = "app", subnet_key = "snet-api" }
    ]
    lifecycle_rules = []
  }

  "backup" = {
    account_tier     = "Standard"
    replication_type = "RAGZRS"
    containers = {
      "backups" = { access_type = "private" }
    }
    allowed_subnet_ids_keys = [
      { vnet_key = "app", subnet_key = "snet-web" },
      { vnet_key = "app", subnet_key = "snet-api" }
    ]
    lifecycle_rules = [
      {
        name                       = "archive-backups"
        prefix_match               = ["backups/"]
        tier_to_cool_after_days    = 7
        tier_to_archive_after_days = 30
        delete_after_days          = 365
      }
    ]
  }
}
