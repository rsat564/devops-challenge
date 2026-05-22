# =============================================================
# DEV Environment - East US
# =============================================================

environment  = "dev"

# Deployer SP in dev has Contributor only (no locks/write); set true once Owner/UAA is granted
enable_management_lock = false
location     = "eastus"
project_name = "cloudops"
cost_center  = "engineering"
owner        = "platform-team"

# Load Balancer placement
lb_vnet_key   = "main"
lb_subnet_key = "snet-app"

# =============================================================
# VNets (scalable - add more keys to create more VNets)
# =============================================================

vnets = {
  "main" = {
    address_space = ["10.10.0.0/16"]
    subnets = {
      "snet-app" = {
        address_prefixes  = ["10.10.1.0/24"]
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      }
      "snet-db" = {
        address_prefixes  = ["10.10.2.0/24"]
        service_endpoints = ["Microsoft.Sql", "Microsoft.KeyVault"]
      }
      "snet-mgmt" = {
        address_prefixes  = ["10.10.3.0/24"]
        service_endpoints = ["Microsoft.KeyVault"]
      }
    }
    nsg_rules = {
      "snet-app" = [
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
          name                       = "AllowHTTP"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "80"
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
      "snet-db" = [
        {
          name                       = "AllowSQLFromApp"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_range     = "1433"
          source_address_prefix      = "10.10.1.0/24"
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
    }
  }
}

# =============================================================
# VMs (scalable - add more keys to create more VMs)
# =============================================================

vms = {
  "web" = {
    vnet_key                      = "main"
    subnet_key                    = "snet-app"
    vm_size                       = "Standard_D2s_v3"
    availability_zone             = "1"
    enable_accelerated_networking = true
    data_disks = {
      "data" = {
        disk_size_gb         = 64
        storage_account_type = "Premium_LRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
    }
  }
}

# =============================================================
# Storage Accounts (scalable - add more keys to create more)
# =============================================================

storage_accounts = {
  "app" = {
    account_tier     = "Standard"
    replication_type = "LRS"
    containers = {
      "data" = { access_type = "private" }
      "logs" = { access_type = "private" }
    }
    allowed_subnet_ids_keys = [
      { vnet_key = "main", subnet_key = "snet-app" }
    ]
    lifecycle_rules = [
      {
        name                       = "archive-logs"
        prefix_match               = ["logs/"]
        tier_to_cool_after_days    = 30
        tier_to_archive_after_days = 90
        delete_after_days          = 365
      },
      {
        name                      = "cleanup-versions"
        version_delete_after_days = 90
      }
    ]
  }
}
