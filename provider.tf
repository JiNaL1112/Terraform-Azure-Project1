# Configure the Azure provider, you can have many
# if you use azurerm provider, it's source is hashicorp/azurerm
# short for registry.terraform.io/hashicorp/azurerm


terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      
      version = "~> 4.14.0"
    }
  }

  required_version = ">= 1.9.0"
}
# configures the provider

provider "azurerm" {
  features {}

  # Tell the provider to use OIDC federated credentials
  use_oidc        = true
  client_id       = var.azure_client_id
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}
