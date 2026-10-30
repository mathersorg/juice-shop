# Registry owned by application=juice-shop. badbankrehzuh stays on the
# Bad Bank application. Public network access stays enabled so the GitHub
# runner can push; the juice-shop nodes pull through the private endpoint.

resource "azurerm_container_registry" "juice" {
  name                          = "juiceshoprehzuh"
  resource_group_name           = "rg-brokenbank-demo"
  location                      = "eastus"
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = true
  network_rule_bypass_option    = "AzureServices"

  network_rule_set {
    default_action = "Deny"
  }

  tags = {
    application = "juice-shop"
    yor_name    = "juice"
    yor_trace   = "46b76e7d-37fa-48fb-9aa3-4c9d25cb22e9"
  }
}

resource "azurerm_private_endpoint" "juice_acr" {
  name                = "juiceshoprehzuh-pe"
  location            = "eastus"
  resource_group_name = "rg-brokenbank-demo"
  subnet_id           = azurerm_subnet.acr_pe.id

  private_service_connection {
    name                           = "juiceshoprehzuh"
    private_connection_resource_id = azurerm_container_registry.juice.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = {
    application = "juice-shop"
    yor_name    = "juice_acr"
    yor_trace   = "6089ae4c-a2d4-42d3-b7be-2b76689c308e"
  }
}
