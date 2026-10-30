import {
  to = azurerm_kubernetes_cluster.juice
  id = "/subscriptions/2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300/resourceGroups/rg-brokenbank-demo/providers/Microsoft.ContainerService/managedClusters/juice-shop"
}

import {
  to = azurerm_private_dns_zone.acr
  id = "/subscriptions/2fd9cc2a-5fbe-4f3a-97e9-cf0e2f000300/resourceGroups/rg-brokenbank-demo/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
}
