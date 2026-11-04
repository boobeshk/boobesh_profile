output "budget_name" {
  description = "Name of the monthly cost budget."
  value       = aws_budgets_budget.monthly.name
}

output "scheduler_function" {
  description = "Lambda that starts and stops tagged EC2 instances."
  value       = aws_lambda_function.scheduler.function_name
}

output "opt_in_tag" {
  description = "Tag to add to an EC2 instance to put it on the office-hours schedule."
  value       = "${var.schedule_tag_key}=${var.schedule_tag_value}"
}
