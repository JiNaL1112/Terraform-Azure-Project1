# 1. Storage account with public access turned off
resource "azurerm_storage_account" "data" {
  name                          = "myappdevdata${random_string.sa.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false   # blocks the public endpoint
  tags                          = local.common_tags
}

resource "random_string" "sa" {
  length  = 6
  upper   = false
  special = false
}

# 2. Private DNS zone for the blob service
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Link the zone to your VNet so VMs use it
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${local.name_prefix}-blob-dnslink"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.test.id
}

# 4. The private endpoint itself (NIC in the mgmt subnet)
resource "azurerm_private_endpoint" "blob" {
  name                = "${local.name_prefix}-blob-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.mgmt_subnet.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = azurerm_storage_account.data.id
    subresource_names              = ["blob"]      # which sub-resource
    is_manual_connection           = false         # auto-approved (same tenant)
  }

  # Automatically creates the A record in the DNS zone
  private_dns_zone_group {
    name                 = "blob-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}