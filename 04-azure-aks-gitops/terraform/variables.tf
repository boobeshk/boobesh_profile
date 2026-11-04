variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralindia"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "lab-aks"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Null uses the region's current default."
  type        = string
  default     = null
}
