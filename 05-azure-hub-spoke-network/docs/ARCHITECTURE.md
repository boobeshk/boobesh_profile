# Architecture: Azure Hub-and-Spoke Network

## Address plan

| Network | Range | Subnets |
|---|---|---|
| Hub | `10.40.0.0/16` | `AzureFirewallSubnet` 10.40.0.0/26, `shared-services` 10.40.1.0/24 |
| Spoke `app` | `10.41.0.0/16` | `workload` 10.41.1.0/24 |
| Spoke `data` | `10.42.0.0/16` | `workload` 10.42.1.0/24 |

Each spoke gets a whole `/16`, leaving room for more subnets (AKS, private endpoints) without re-addressing.

## Traffic flows (with `deploy_firewall = true`)

| Flow | Path | Control |
|---|---|---|
| app → data (east-west) | app subnet → route table → firewall → data | Network rule: TCP 443, 1433, 5432 only |
| spoke → internet (egress) | spoke subnet → route table → firewall → internet | Application rule: approved FQDNs only |
| internet → spoke (ingress) | blocked | NSG `DenyInternetInbound`; no public IPs in spokes |
| hub ↔ spoke | VNet peering | Forwarded traffic allowed so the firewall can route |

Without the firewall, spokes can reach the hub but **not each other**. Peering isn't transitive, which is the
isolation the design relies on.

## Design decisions

- **No spoke-to-spoke peering.** Every east-west flow is visible and filtered in one place.
- **Firewall Policy, not classic rules.** Policies can be shared across firewalls and regions, and support rule
  collection groups with priorities.
- **NSGs even behind the firewall.** If a route is changed by mistake, the subnet is still protected.
- **`for_each` over a map of spokes.** Adding or removing a spoke changes only that spoke's resources, never re-indexes others.
- **Firewall behind a feature flag.** Learners can build the network for free and add the firewall when needed.

## Production hardening (next steps)

- Firewall Premium with TLS inspection and IDPS, and diagnostic logs to Log Analytics.
- VPN Gateway or ExpressRoute in the hub for on-premises connectivity (`use_remote_gateways` on spoke peerings).
- Azure Bastion in the hub for admin access without public IPs.
- Private DNS zones linked to the hub for private endpoints.
- Azure Policy to deny public IPs and enforce NSGs on every subnet.
