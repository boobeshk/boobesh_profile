locals {
  # EventBridge cron runs in UTC: 14:30 UTC = 20:00 IST, 03:00 UTC = 08:30 IST.
  schedules = {
    stop  = "cron(30 14 ? * MON-FRI *)"
    start = "cron(0 3 ? * MON-FRI *)"
  }
}

# ---------- Budget alerts ----------

resource "aws_budgets_budget" "monthly" {
  name         = "monthly-cost-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Early warning: forecast says we'll pass 80% this month.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  # Hard signal: actual spend passed the budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# ---------- Cost anomaly detection ----------

resource "aws_ce_anomaly_monitor" "services" {
  name              = "service-spend-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "daily" {
  name             = "daily-anomaly-alerts"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }
}

# ---------- Office-hours EC2 scheduler ----------

data "archive_file" "scheduler" {
  type        = "zip"
  source_file = "${path.module}/../src/scheduler.py"
  output_path = "${path.module}/build/scheduler.zip"
}

data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "ec2-office-hours-scheduler"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid       = "FindInstances"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  # Start/stop is allowed only on instances that carry the opt-in tag.
  statement {
    sid       = "StartStopTaggedInstances"
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.schedule_tag_key}"
      values   = [var.schedule_tag_value]
    }
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.scheduler.arn}:*"]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "ec2-office-hours-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_cloudwatch_log_group" "scheduler" {
  name              = "/aws/lambda/ec2-office-hours-scheduler"
  retention_in_days = 30
}

resource "aws_lambda_function" "scheduler" {
  function_name    = "ec2-office-hours-scheduler"
  role             = aws_iam_role.scheduler.arn
  runtime          = "python3.12"
  handler          = "scheduler.handler"
  filename         = data.archive_file.scheduler.output_path
  source_code_hash = data.archive_file.scheduler.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      TAG_KEY   = var.schedule_tag_key
      TAG_VALUE = var.schedule_tag_value
    }
  }

  depends_on = [aws_cloudwatch_log_group.scheduler, aws_iam_role_policy.scheduler]
}

resource "aws_cloudwatch_event_rule" "schedule" {
  for_each = local.schedules

  name                = "ec2-office-hours-${each.key}"
  description         = "Office-hours scheduler: ${each.key} tagged instances."
  schedule_expression = each.value
}

resource "aws_cloudwatch_event_target" "schedule" {
  for_each = local.schedules

  rule  = aws_cloudwatch_event_rule.schedule[each.key].name
  arn   = aws_lambda_function.scheduler.arn
  input = jsonencode({ action = each.key })
}

resource "aws_lambda_permission" "events" {
  for_each = local.schedules

  statement_id  = "AllowEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[each.key].arn
}
