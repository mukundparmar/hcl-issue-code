output "dashboard_individual_per-logical-group" {
  description = "URLs to CloudWatch Individual Metric Dashboards by Logical Grouping"
  value = [
    for dashboard in aws_cloudwatch_dashboard.per-logical-group:
      "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${dashboard.dashboard_name}"
  ]
}

output "cross_service_dashboard" {
  description = "URL to regional cross-service CloudWatch Dashboard, which shows default statistics AWS considers relevant"
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#cw:dashboard=Overview"
}
