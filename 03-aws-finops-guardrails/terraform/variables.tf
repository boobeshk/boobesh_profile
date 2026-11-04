variable "region" {
  description = "AWS region for the scheduler function."
  type        = string
  default     = "ap-south-1"
}

variable "alert_email" {
  description = "Email address that receives budget and anomaly alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 100
}

variable "anomaly_threshold_usd" {
  description = "Alert when a cost anomaly's total impact reaches this many USD."
  type        = number
  default     = 20
}

variable "schedule_tag_key" {
  description = "Tag key that opts an EC2 instance into the office-hours schedule."
  type        = string
  default     = "Schedule"
}

variable "schedule_tag_value" {
  description = "Tag value that opts an EC2 instance into the office-hours schedule."
  type        = string
  default     = "office-hours"
}
