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
      source_address_prefix      = "AzureLoadBalancer"  # Only LB, not "*"
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
      source_address_prefix      = "AzureLoadBalancer"  # Only LB, not "*"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      # SSH is routed through the LB NAT rules (ports 50000-50119 → 22)
      # so its source is still AzureLoadBalancer
      name                       = "allow-ssh-from-lb"
      priority                   = 102
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "AzureLoadBalancer"  # Only LB NAT, not "*"
      destination_address_prefix = "VirtualNetwork"
    },
    {
      # Catch-all deny — blocks every other inbound connection
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
