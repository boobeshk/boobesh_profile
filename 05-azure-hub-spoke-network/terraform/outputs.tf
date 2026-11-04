output "hub_vnet_id" {
  description = "ID of the hub VNet."
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  description = "IDs of the spoke VNets, keyed by spoke name."
  value       = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "firewall_private_ip" {
  description = "Private IP of the hub firewall (null when deploy_firewall is false)."
  value       = var.deploy_firewall ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null
}
