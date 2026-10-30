# Private path from the juice-shop nodes to badbankrehzuh.
# Public network access stays enabled so the GitHub runner can still push
# and the lab VM can still pull over its subnet rule.

data "azurerm_virtual_network" "lab" {
  name                = "badbank-vnet"
  resource_group_name = "rg-brokenbank-demo"
}

data "azurerm_resources" "aks_vnet" {
  resource_group_name = "MC_rg-brokenbank-demo_juice-shop_eastus"
  type                = "Microsoft.Network/virtualNetworks"
}

data "azurerm_virtual_network" "aks" {
  name                = data.azurerm_resources.aks_vnet.resources[0].name
  resource_group_name = "MC_rg-brokenbank-demo_juice-shop_eastus"
}

resource "azurerm_subnet" "acr_pe" {
  name                 = "badbank-acr-pe"
  resource_group_name  = "rg-brokenbank-demo"
  virtual_network_name = data.azurerm_virtual_network.lab.name
  address_prefixes     = ["10.40.2.0/24"]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = "rg-brokenbank-demo"

  tags = {
    application          = "juice-shop"
    yor_name             = "acr"
    yor_trace            = "5d47dd58-305e-4794-9698-46730c3671d7"
    git_commit           = "b7f733b4ba9dc51787a9da9c81b4ff77675e8171"
    git_file             = "infra/aks/private-endpoint.tf"
    git_last_modified_at = "2026-10-29 20:54:51"
    git_last_modified_by = "smathers@digitalgatekeepers.com"
    git_modifiers        = "smathers"
    git_org              = "mathersorg"
    git_repo             = "juice-shop"
  }
}

# badbank-vnet is already linked to privatelink.azurecr.io. A zone can
# link to each virtual network only once, so this stack does not create
# a second link for the lab VNet.

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "juice-shop-vnet"
  resource_group_name   = "rg-brokenbank-demo"
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = data.azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags = {
    yor_name             = "aks"
    yor_trace            = "819e7707-19d7-4f28-aff2-3369bf281eb4"
    git_commit           = "b7f733b4ba9dc51787a9da9c81b4ff77675e8171"
    git_file             = "infra/aks/private-endpoint.tf"
    git_last_modified_at = "2026-10-29 20:54:51"
    git_last_modified_by = "smathers@digitalgatekeepers.com"
    git_modifiers        = "smathers"
    git_org              = "mathersorg"
    git_repo             = "juice-shop"
  }
}

resource "azurerm_private_endpoint" "acr" {
  name                = "badbankrehzuh-pe"
  location            = "eastus"
  resource_group_name = "rg-brokenbank-demo"
  subnet_id           = azurerm_subnet.acr_pe.id

  private_service_connection {
    name                           = "badbankrehzuh"
    private_connection_resource_id = "/subscriptions/2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300/resourceGroups/rg-brokenbank-demo/providers/Microsoft.ContainerRegistry/registries/badbankrehzuh"
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = {
    application          = "juice-shop"
    yor_name             = "acr"
    yor_trace            = "d754000b-170a-4ff6-a831-9fa65f094f5c"
    git_commit           = "b7f733b4ba9dc51787a9da9c81b4ff77675e8171"
    git_file             = "infra/aks/private-endpoint.tf"
    git_last_modified_at = "2026-10-29 20:54:51"
    git_last_modified_by = "smathers@digitalgatekeepers.com"
    git_modifiers        = "smathers"
    git_org              = "mathersorg"
    git_repo             = "juice-shop"
  }
}

resource "azurerm_virtual_network_peering" "lab_to_aks" {
  name                         = "lab-to-juice-shop"
  resource_group_name          = "rg-brokenbank-demo"
  virtual_network_name         = data.azurerm_virtual_network.lab.name
  remote_virtual_network_id    = data.azurerm_virtual_network.aks.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "aks_to_lab" {
  name                         = "juice-shop-to-lab"
  resource_group_name          = "MC_rg-brokenbank-demo_juice-shop_eastus"
  virtual_network_name         = data.azurerm_virtual_network.aks.name
  remote_virtual_network_id    = data.azurerm_virtual_network.lab.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
