locals {
  tags = {
    project   = "lab-aks-gitops"
    managedBy = "terraform"
    owner     = "boobesh-k"
  }
}

resource "azurerm_resource_group" "aks" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "aks" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = ["10.30.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "aks-nodes"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.30.0.0/20"]
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.name_prefix}-logs"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name_prefix}-cluster"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  # Workload identity lets pods use Entra ID without stored secrets.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true

  # System pool: cluster add-ons only.
  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    vnet_subnet_id               = azurerm_subnet.nodes.id
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 3
    os_disk_size_gb              = 64
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "10.31.0.0/16"
    dns_service_ip    = "10.31.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = local.tags
}

# User pool: application workloads, scaled independently of the system pool.
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v5"
  vnet_subnet_id        = azurerm_subnet.nodes.id
  auto_scaling_enabled  = true
  min_count             = 1
  max_count             = 5
  mode                  = "User"

  node_labels = {
    workload = "apps"
  }

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.tags
}
