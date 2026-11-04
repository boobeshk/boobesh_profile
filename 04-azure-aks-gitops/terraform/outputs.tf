output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "get_credentials" {
  description = "Command that points kubectl at the new cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "oidc_issuer_url" {
  description = "OIDC issuer used for workload identity federation."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}
