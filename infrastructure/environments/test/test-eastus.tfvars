# =============================================================
# TEST Environment - East US 
# =============================================================

environment  = "test"
location     = "eastus"
project_name = "cloudops"
cost_center  = "engineering"
owner        = "platform-team"

# Load Balancer placement
lb_vnet_key   = "main"
lb_subnet_key = "snet-app"

# =============================================================
# VNets
# =============================================================

vnets = {
  "main" = {
    address_space = ["10.20.0.0/16"]
    subnets = {
      "snet-app" = {
        address_prefixes  = ["10.20.1.0/24"]
        service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
      }
      "snet-db" = {
        address_prefixes  = ["10.20.2.0/24"]
        service_endpoints = ["Microsoft.Sql"]
      }
      "snet-mgmt" = {
        address_prefixes  = ["10.20.3.0/24"]
        service_endpoints = []
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
          source_address_prefix      = "10.20.1.0/24"
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
# VMs (2 VMs in test for load testing)
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
        disk_size_gb         = 128
        storage_account_type = "Premium_LRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
    }
  }
  "worker" = {
    vnet_key                      = "main"
    subnet_key                    = "snet-app"
    vm_size                       = "Standard_D2s_v3"
    availability_zone             = "2"
    enable_accelerated_networking = true
    data_disks = {
      "data" = {
        disk_size_gb         = 128
        storage_account_type = "Premium_LRS"
        lun                  = 0
        caching              = "ReadOnly"
      }
    }
  }
}

# =============================================================
# Storage Accounts
# =============================================================

storage_accounts = {
  "app" = {
    account_tier     = "Standard"
    replication_type = "GZRS"
    containers = {
      "data"    = { access_type = "private" }
      "logs"    = { access_type = "private" }
      "backups" = { access_type = "private" }
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
