# ============================================================
# variables.tf
# All input variables for the infrastructure.
# Values are set in terraform.tfvars.
# ============================================================

# ---------------------
# Core project settings
# ---------------------
variable "environment" {
  description = "Deployment environment name (dev, stage, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "prefix" {
  description = "Short prefix used in all resource names (e.g. 'myapp')"
  type        = string
}

# ---------------------
# Region — RESTRICTED
# ---------------------
variable "region" {
  description = "Azure region to deploy into. Only three values are allowed."
  type        = string

  # Assignment requirement: restrict to East US, West Europe, Southeast Asia
  validation {
    condition = contains(
      ["eastus", "westeurope", "southeastasia","centralindia"],
      var.region
    )
    error_message = "region must be one of: eastus, westeurope, southeastasia, centralindia."
  }
}

# ---------------------
# Scaling
# ---------------------
variable "min_instances" {
  description = "Minimum number of VMSS instances"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of VMSS instances"
  type        = number
  default     = 3
}

variable "default_instances" {
  description = "Default/initial number of VMSS instances"
  type        = number
  default     = 2
}

# ---------------------
# Networking
# ---------------------
variable "vnet_address_space" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_subnet_prefix" {
  description = "CIDR block for the application subnet (VMSS lives here)"
  type        = string
  default     = "10.0.0.0/20"
}

variable "mgmt_subnet_prefix" {
  description = "CIDR block for the management subnet (reserved for future use)"
  type        = string
  default     = "10.0.16.0/24"
}


variable "azure_client_id" {
  description = "Azure Client ID (from GitHub secret)"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID (from GitHub secret)"
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID (from GitHub secret)"
  type        = string
}


variable "my_ip" {
  description = "Public IP (CIDR) allowed to SSH, e.g. 203.0.113.25/32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.my_ip)) && var.my_ip != "0.0.0.0/0"
    error_message = "my_ip must be a valid CIDR and must not be 0.0.0.0/0."
  }
}
