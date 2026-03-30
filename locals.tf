# ============================================================
# locals.tf
# Centralized locals for tags, naming, and NSG rule definitions
# ============================================================

locals {

  # ---------------------
  # Common Tags
  # ---------------------
  common_tags = {
    environment = var.environment
    project     = var.prefix
    region      = var.region
    managed_by  = "terraform"
  }

  # ---------------------
  # Resource Naming
  # ---------------------
  name_prefix = "${var.prefix}-${var.environment}"

  # ---------------------
  # NSG Rules
  # Only allow traffic originating from the Azure Load Balancer.
  # A final deny-all rule blocks everything else.
  # ---------------------
  nsg_rules = [
    {
      name                       = "allow-http-from-lb"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"              # clients reach via LB only since VMSS has no PIP
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "allow-https-from-lb"
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      # SSH health probes and NAT rules genuinely come from LB probe IP
      # so AzureLoadBalancer tag works correctly here
      name                       = "allow-ssh-from-lb"
      priority                   = 102
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      # Health probe traffic from Azure platform
      name                       = "allow-health-probe"
      priority                   = 103
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      name                       = "deny-all-inbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
}
