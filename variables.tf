variable "region" {
  description = "Region for dashboards and Cloudwatch Metrics. Current region 'data \"aws_region\" \"current\" {}' used if none provided."
  default     = "us-east-2"
  type        = string
}
variable "dashboard_hierarchy" {
  description = "Feeds resource aws_cloudwatch_dashboard.per-logical-group for_each = var.dashboard_hierarchy"
  type        = map(object({
    metric_target_tags = map(string)
    metric_targets = list(string)
    metrics            = list(object({
      statistic   = string
      period      = number
      metric_name = string
      metric_path = list(string)
    }))
  }))

  default = {
    WebServers = { # Dashboard
      metric_target_tags =  {
        Environment = "EnvironmentType"
        ServerType = "WebInstance"
      }
      metric_targets = []
      metrics = [
        { # The same CPU Utilization Metric will be graphed in a single Widget for all EC2 Instances
          statistic   = "Average"
          period      = 60
          metric_name = "CPUUtilization"
          metric_path = ["AWS/EC2", "CPUUtilization", "InstanceId"]
        },
        { # A second Widget with NetworkIn, again all graphed in a single Widget for all EC2 Instances
          statistic   = "Maximum"
          period      = 300
          metric_name = "NetworkIn=m1"
          metric_path = ["AWS/EC2", "NetworkIn", "InstanceId"]
        },
        { # A third Widget with NetworkOut, again all graphed in a single Widget for all EC2 Instances
          statistic   = "Maximum"
          period      = 300
          metric_name = "NetworkOut=m2"
          metric_path = ["AWS/EC2", "NetworkOut", "InstanceId"]
        },
        { # A fourth Widget with a Metric Expression based on the NetworkIn and NetworkOut
          statistic   = "expression"
          period      = 300
          metric_name = "InstanceName Network Gb/s"
          metric_path = ["((m1+m2)*8)/1024/1024/1024/PERIOD(m1)"]
        }
      ]
    }
  }
}
