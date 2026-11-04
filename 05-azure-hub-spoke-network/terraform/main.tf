locals {
  spoke_ranges = [for s in var.spokes : s.address_space]

  tags = {
    project   = "lab-hub-spoke"
    managedBy = "terraform"
    owner     = "boobesh-k"
  }
}

resource "azurerm_resource_group" "net" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

# ---------- Hub ----------

resource "azurerm_virtual_network" "hub" {
  name                = "${var.name_prefix}-hub-vnet"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [var.hub_address_space]
  tags                = local.tags
}

# Azure requires this exact subnet name for Azure Firewall.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 10, 0)]
}

resource "azurerm_subnet" "shared" {
  name                 = "shared-services"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 1)]
}

# ---------- Spokes ----------

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "${var.name_prefix}-${each.key}-vnet"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [each.value.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  for_each = var.spokes

  name                 = "workload"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.workload_prefix]
}

resource "azurerm_network_security_group" "workload" {
  for_each = var.spokes

  name                = "${var.name_prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags

  security_rule {
    name                       = "AllowHttpsFromVnets"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = var.spokes

  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}

# ---------- Peering (hub <-> each spoke; spokes are never peered to each other) ----------

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.net.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.net.name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# ---------- Optional Azure Firewall ----------

resource "azurerm_public_ip" "firewall" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.name_prefix}-fw-pip"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "hub" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.name_prefix}-fw-policy"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "hub" {
  count = var.deploy_firewall ? 1 : 0

  name               = "default-rules"
  firewall_policy_id = azurerm_firewall_policy.hub[0].id
  priority           = 100

  # East-west: spokes may talk to each other only on these ports, through the firewall.
  network_rule_collection {
    name     = "spoke-to-spoke"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "app-and-db-ports"
      protocols             = ["TCP"]
      source_addresses      = local.spoke_ranges
      destination_addresses = local.spoke_ranges
      destination_ports     = ["443", "1433", "5432"]
    }
  }

  # North-south: outbound web only to approved FQDNs.
  application_rule_collection {
    name     = "outbound-web"
    priority = 200
    action   = "Allow"

    rule {
      name              = "os-and-package-updates"
      source_addresses  = local.spoke_ranges
      destination_fqdns = ["*.ubuntu.com", "packages.microsoft.com", "*.docker.io"]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "hub" {
  count = var.deploy_firewall ? 1 : 0

  name                = "${var.name_prefix}-fw"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id
  tags                = local.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

# Send all spoke traffic (internet and other spokes) to the firewall.
resource "azurerm_route_table" "spoke" {
  for_each = var.deploy_firewall ? var.spokes : {}

  name                = "${var.name_prefix}-${each.key}-rt"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.deploy_firewall ? var.spokes : {}

  subnet_id      = azurerm_subnet.workload[each.key].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}
