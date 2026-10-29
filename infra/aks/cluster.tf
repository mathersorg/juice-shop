resource "azurerm_kubernetes_cluster" "juice" {
  automatic_upgrade_channel           = "patch"
  azure_policy_enabled                = false
  cost_analysis_enabled               = false
  dns_prefix                          = "juice-shop-dns"
  http_application_routing_enabled    = false
  image_cleaner_enabled               = true
  image_cleaner_interval_hours        = 168
  kubernetes_version                  = "1.36.4"
  local_account_disabled              = false
  location                            = "eastus"
  name                                = "juice-shop"
  node_os_upgrade_channel             = "NodeImage"
  node_resource_group                 = "MC_rg-brokenbank-demo_juice-shop_eastus"
  oidc_issuer_enabled                 = true
  open_service_mesh_enabled           = false
  private_cluster_enabled             = false
  private_cluster_public_fqdn_enabled = false
  resource_group_name                 = "rg-brokenbank-demo"
  role_based_access_control_enabled   = true
  run_command_enabled                 = true
  sku_tier                            = "Free"
  support_plan                        = "KubernetesOfficial"
  workload_identity_enabled           = true

  tags = {
    application = "juice-shop"
  }

  auto_scaler_profile {
    balance_similar_node_groups                   = false
    daemonset_eviction_for_empty_nodes_enabled    = false
    daemonset_eviction_for_occupied_nodes_enabled = true
    empty_bulk_delete_max                         = "10"
    expander                                      = "random"
    ignore_daemonsets_utilization_enabled         = false
    max_graceful_termination_sec                  = "600"
    max_node_provisioning_time                    = "15m"
    max_unready_nodes                             = 3
    max_unready_percentage                        = 45
    new_pod_scale_up_delay                        = "0s"
    scale_down_delay_after_add                    = "10m"
    scale_down_delay_after_delete                 = "10s"
    scale_down_delay_after_failure                = "3m"
    scale_down_unneeded                           = "10m"
    scale_down_unready                            = "20m"
    scale_down_utilization_threshold              = "0.5"
    scan_interval                                 = "10s"
    skip_nodes_with_local_storage                 = false
    skip_nodes_with_system_pods                   = true
  }

  bootstrap_profile {
    artifact_source = "Direct"
  }

  default_node_pool {
    auto_scaling_enabled         = true
    fips_enabled                 = false
    host_encryption_enabled      = false
    kubelet_disk_type            = "OS"
    max_count                    = 3
    max_pods                     = 110
    min_count                    = 2
    name                         = "agentpool"
    node_count                   = 2
    node_public_ip_enabled       = false
    only_critical_addons_enabled = false
    orchestrator_version         = "1.36.4"
    os_disk_size_gb              = 128
    os_disk_type                 = "Managed"
    os_sku                       = "Ubuntu"
    scale_down_mode              = "Delete"
    type                         = "VirtualMachineScaleSets"
    ultra_ssd_enabled            = false
    vm_size                      = "Standard_DC2ads_v5"
    zones                        = ["2", "3"]

    tags = {
      application = "bad-bank-azure-demo"
    }

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  maintenance_window_auto_upgrade {
    day_of_month = 0
    day_of_week  = "Sunday"
    duration     = 8
    frequency    = "Weekly"
    interval     = 1
    start_date   = "2026-10-29T00:00:00Z"
    start_time   = "00:00"
    utc_offset   = "+00:00"
  }

  maintenance_window_node_os {
    day_of_month = 0
    day_of_week  = "Sunday"
    duration     = 8
    frequency    = "Weekly"
    interval     = 1
    start_date   = "2026-10-29T00:00:00Z"
    start_time   = "00:00"
    utc_offset   = "+00:00"
  }

  network_profile {
    dns_service_ip      = "10.0.0.10"
    ip_versions         = ["IPv4"]
    load_balancer_sku   = "standard"
    network_data_plane  = "azure"
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    outbound_type       = "loadBalancer"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"

    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  lifecycle {
    ignore_changes = [
      kubernetes_version,
      kubelet_identity,
      windows_profile,
      default_node_pool[0].node_count,
      default_node_pool[0].orchestrator_version,
      default_node_pool[0].upgrade_settings,
      network_profile[0].load_balancer_profile,
    ]
  }
}
