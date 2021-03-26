data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

provider "aws" {
  region = var.region
}

locals {
  tags_per_dashboard = {for k, v in var.dashboard_hierarchy: k => v.metric_target_tags if length(keys(v.metric_target_tags)) != 0}
  targets_by_type    = {for k, v in var.dashboard_hierarchy: k => [for path in v.metrics: path.metric_path[length(path.metric_path) - 1]]}
  target_instances   = {for k, v in local.tags_per_dashboard: k => v if v != {} && contains(local.targets_by_type[k], "InstanceId")}
  target_instances_per_dashboard = {for k in keys(local.target_instances): k => data.aws_instances.metric_targets[k].ids} # All targets which requires InstanceId.
  targets_per_dashboard = {for k, v in var.dashboard_hierarchy: k => v.metric_targets if length(v.metric_targets) != 0} # to find all targets except InstanceIds.
  metric_path = ["((m1+m2)*8)/1024/1024/1024/PERIOD(m1)"]
}

data "aws_instances" "metric_targets" {
  for_each             = local.target_instances
  instance_tags        = each.value # metric_target_tags
  instance_state_names = ["running", "stopped"]
}

resource "aws_cloudwatch_dashboard" "per-logical-group" {
  for_each       = var.dashboard_hierarchy
  dashboard_name = each.key

  dashboard_body = <<-EOF
    {
      "widgets": [
        ${join(",", [for metric in each.value.metrics : templatefile("widget.tmpl", {
          # X/Y coordinates of the matrix of Widgets in the Dashboard
          x_offset    = (index(each.value.metrics, metric) % 2) * 12,
          y_offset    = (index(each.value.metrics, metric) - (index(each.value.metrics, metric) % 2)) * 7,
          # Either (a) insert a Metric Expression, or (b) use the Metric Path + Resource ID
          metric_code = jsonencode(
            # For every target EC2 Instance for a given Dashboard Widget, append the InstanceID to the Metric Path
            coalescelist(concat(
              [for k, v in local.targets_per_dashboard: concat(metric.metric_path, v) if k == each.key],
              contains(keys(local.target_instances_per_dashboard), each.key) ?
              # for every instance associated with this dashboard and metric
              coalescelist([for k, v in local.target_instances_per_dashboard: [for i in v:
                metric.statistic == "expression" ?
                # For every Metric Expression for a given Dashboard Widget, insert the Expression as well as the Metrics referenced by the Expression
                # [ { "expression": "((m1+m2)*8)/1024/1024/1024/PERIOD(m1)", "label": "InstanceName Network Gb/s"} ]
                # flatten(regexall("m(\\d+)","((m1+m2)*8)/1024/1024/1024/PERIOD(m1)")) => ["1", "2", "1"]
                [jsonencode({"expression": replace(replace(replace(replace(replace(replace(replace(replace(replace(metric.metric_path[0], "m1", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 0 ? 1 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 1}"), "m2", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 1 ? 2 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 2}"), "m3", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 2 ? 3 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 3}"), "m4", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 3 ? 4 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 4}"), "m5", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 4 ? 5 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 5}"), "m6", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 5 ? 6 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 6}"), "m7", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 6 ? 7 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 7}"), "m8", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 7 ? 8 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 8}"), "m9", "m${length(flatten(distinct(regexall("m(\\d+?)", metric.metric_path[0])))) > 8 ? 9 + (length(local.target_instances_per_dashboard[k]) * index(local.target_instances_per_dashboard[k], i)) : 9}"), "label": metric.metric_name})] :
                # {"expression": "((NetworkIn+NetworkOut)*8)/1024/1024/1024/PERIOD(NetworkIn)"}
                # [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxx" ]
                tolist(concat(metric.metric_path, [i],
                # If the metric_name has suffix like "=m1", append metadata as follows.
                length(regexall(".*=m(\\d+)", metric.metric_name)) > 0 ?
                # regexall(".*=m(\\d+)", metric.metric_name) => "1" if "NetworkIn=m1", "99" if "NetworkOut=m99", etc.
                # Cast "1" or "99" to 1 or 99
                # Multiply the ID (1, 99, etc.) by the index of the Resource/Instance
                [jsonencode({"visible": false, "id": "m${tonumber(regexall(".*=m(\\d+)", metric.metric_name)[0][0]) + (length(local.target_instances_per_dashboard[k]) *
                index(local.target_instances_per_dashboard[k], i))}"})] : [])) if k == each.key]]...) : []
            ))
          ),
          period      = jsonencode(metric.period),
          stat        = jsonencode(metric.statistic),
          region      = jsonencode(var.region),
          title = jsonencode("${each.key}-${metric.metric_name}-${metric.statistic}") })])
        }
      ]
    }
  EOF
}

output "metric_target_ids" {
  value = local.targets_per_dashboard
}

