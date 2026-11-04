variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "lab-items-api"
}
