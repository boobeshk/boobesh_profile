output "api_url" {
  description = "Base URL of the HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "table_name" {
  description = "DynamoDB table that stores the items."
  value       = aws_dynamodb_table.items.name
}
