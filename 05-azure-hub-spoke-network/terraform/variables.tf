variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralindia"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "lab-net"
}

variable "hub_address_space" {
  description = "Address space of the hub VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "deploy_firewall" {
  description = "Deploy Azure Firewall in the hub and route spoke traffic through it (about USD 1.25/hour)."
  type        = bool
  default     = false
}

variable "spokes" {
  description = "Spoke VNets to create, keyed by name."

  type = map(object({
    address_space   = string
    workload_prefix = string
  }))

  default = {
    app = {
      address_space   = "10.41.0.0/16"
      workload_prefix = "10.41.1.0/24"
    }
    data = {
      address_space   = "10.42.0.0/16"
      workload_prefix = "10.42.1.0/24"
    }
  }
}
