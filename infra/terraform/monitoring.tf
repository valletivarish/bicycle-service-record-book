# Alarm notifications. The e-mail subscription is added once with the CLI
# (aws sns subscribe), so no personal address is kept in this repository.
resource "aws_sns_topic" "alerts" {
  # checkov:skip=CKV_AWS_26:alarm messages carry no secrets; the default key avoids a KMS key charge
  name = "service-book-alerts"
}

# CPU of the API host: the resource utilisation metric for the report.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "service-book-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.api.id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  alarm_description   = "API host CPU above 70% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# AppHealthy is pushed every minute by the health timer on the host
# (1 = /api/health answered through Nginx, Node and RDS, 0 = it did not).
resource "aws_cloudwatch_metric_alarm" "app_unhealthy" {
  alarm_name          = "service-book-unhealthy"
  namespace           = "ServiceBook"
  metric_name         = "AppHealthy"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_description   = "Health check failed for 3 minutes in a row"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "service-book"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Application health (1 = healthy)"
          region  = var.region
          stat    = "Minimum"
          period  = 60
          metrics = [["ServiceBook", "AppHealthy"]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "API host CPU %"
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.api.id]]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "RDS CPU %"
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier]]
        }
      }
    ]
  })
}
