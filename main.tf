# References:
#  Target tracking: https://segment.com/blog/when-aws-autoscale-doesn-t/
#     ECS cluster should scale based on pending task. Figure out how

# Make this it's own module: terraform-aws-ecs-service-autoscale-step-sqs
/*
Autoscaling: ECS service, cloudwatch alarms, application autoscaling
Look at prod-semzen-ocr
4 alarms: down (cpu), up (cpu), queue-down, queue-up

/**/

# Outputs ?

module "label" {
  source     = "appzen-oss/label/local"
  version    = "0.3.1"
  attributes = "${var.attributes}"
  component  = "${var.component}"
  delimiter  = "${var.delimiter}"

  #enabled       = "${module.enabled.value}"
  environment   = "${var.environment}"
  monitor       = "${var.monitor}"
  name          = "${var.name}"
  namespace-env = "${var.namespace-env}"
  namespace-org = "${var.namespace-org}"
  organization  = "${var.organization}"
  owner         = "${var.owner}"
  product       = "${var.product}"
  service       = "${var.service}"
  tags          = "${var.tags}"
  team          = "${var.team}"
}

##
## Autoscaling IAM
##
resource "aws_iam_role" "ecs_service_autoscale" {
  name = "${module.label.id}-ecs-service-autoscale"
  tags = "${module.label.tags}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Autoscaling",
      "Effect": "Allow",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Managed IAM Policy for ECS service autoscaling
resource "aws_iam_role_policy_attachment" "ecs_service_autoscale" {
  role       = "${aws_iam_role.ecs_service_autoscale.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

##
## Autoscaling Target
##
resource "aws_appautoscaling_target" "target" {
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  role_arn           = "${aws_iam_role.ecs_service_autoscale.arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = "${var.min_capacity}"
  max_capacity       = "${var.max_capacity}"
  service_namespace  = "ecs"
}

##
## Autoscaling Policies
##
resource "aws_appautoscaling_policy" "scale_up" {
  count = "${
    var.high_threshold > 0
    ? 1 : 0}"

  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-sqs-up"
  policy_type        = "StepScaling"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_up_cooldown}"
    adjustment_type          = "${var.adjustment_type_up}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_up_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_up_lower_bound}"
      metric_interval_upper_bound = "${var.scale_up_upper_bound}"
      scaling_adjustment          = "${var.scale_up_count}"
    }
  }
}

resource "aws_appautoscaling_policy" "scale_big_up" {
  count = "${
    var.high_big_threshold > 0
    ? 1 : 0}"

  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-sqs-big-up"
  policy_type        = "StepScaling"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_big_up_cooldown}"
    adjustment_type          = "${var.adjustment_type_up}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_up_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_up_lower_bound}"
      metric_interval_upper_bound = "${var.scale_up_upper_bound}"
      scaling_adjustment          = "${var.scale_big_up_count}"
    }
  }
}

resource "aws_appautoscaling_policy" "scale_queuetime_up" {
  count = "${
    var.queue_up_threshold > 0
    ? 1 : 0}"

  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-queuetime-up"
  policy_type        = "StepScaling"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_up_cooldown}"
    adjustment_type          = "${var.adjustment_type_up}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_up_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_up_lower_bound}"
      metric_interval_upper_bound = "${var.scale_up_upper_bound}"
      scaling_adjustment          = "${var.scale_up_count}"
    }
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  count = "${
    var.low_threshold >= 0
    ? 1 : 0}"

  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-queuetime-down"
  policy_type        = "StepScaling"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_down_cooldown}"
    adjustment_type          = "${var.adjustment_type_down}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_down_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_down_lower_bound}"
      metric_interval_upper_bound = "${var.scale_down_upper_bound}"
      scaling_adjustment          = "${var.scale_down_count}"
    }
  }
}

##
## Cloudwatch Alarms
##
resource "aws_cloudwatch_metric_alarm" "service_max_stuck" {
  count = "${
    var.stuck_eval_minutes > 0
    ? 1 : 0}"

  alarm_name                = "${module.label.id}-max-stuck"
  alarm_description         = "${module.label.id} is possibly stuck at max"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "${var.stuck_eval_minutes}"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "${floor(var.max_capacity * 0.9)}"
  actions_enabled           = "true"
  alarm_actions             = ["${var.sns_stuck_alarm_arn}"]
  ok_actions                = ["${var.sns_stuck_alarm_arn}"]
  insufficient_data_actions = []
  treat_missing_data        = "ignore"

  dimensions = {
    ClusterName = "${var.cluster_name}"
    ServiceName = "${var.service_name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "service_queue_high" {
  count = "${
    var.high_threshold > 0
    ? 1 : 0}"

  alarm_name          = "${module.label.id}-sqs-up"
  alarm_description   = "This alarm monitors ${var.queue_name} Queue count utilization for scaling up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "${var.high_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_up.arn}"]

  #  namespace           = "AWS/SQS"
  #  period              = "60"
  #  statistic           = "Average"
  #  metric_name         = "ApproximateNumberOfMessagesVisible"

  metric_query {
    id          = "e1"
    expression  = "visible+notvisible"
    label       = "Sum_Visible+NonVisible"
    return_data = "true"
  }
  metric_query {
    id = "visible"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #      unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
  metric_query {
    id = "notvisible"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #  unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "service_queue_big_high" {
  count = "${
    var.high_big_threshold > 0
    ? 1 : 0}"

  alarm_name          = "${module.label.id}-sqs-big-up"
  alarm_description   = "This alarm monitors ${var.queue_name} Queue count utilization for big scaling up"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "${var.high_big_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_big_up.arn}"]

  #  namespace           = "AWS/SQS"
  #  period              = "60"
  #  statistic           = "Average"
  #  metric_name         = "ApproximateNumberOfMessagesVisible"

  metric_query {
    id          = "e1"
    expression  = "visible+notvisible"
    label       = "Sum_Visible+NonVisible"
    return_data = "true"
  }
  metric_query {
    id = "visible"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #      unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
  metric_query {
    id = "notvisible"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #  unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
}

# A CloudWatch alarm that monitors CPU utilization of containers for scaling down
resource "aws_cloudwatch_metric_alarm" "service_queue_low" {
  count = "${
    var.low_threshold >= 0
    ? 1 : 0}"

  alarm_name          = "${module.label.id}-sqs-down"
  alarm_description   = "This alarm monitors ${var.queue_name} Queue count utilization for scaling down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  threshold           = "${var.low_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_down.arn}"]

  metric_query {
    id          = "e1"
    expression  = "visible+notvisible"
    label       = "Sum_Visible+NonVisible"
    return_data = "true"
  }

  metric_query {
    id = "visible"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #  unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }

  metric_query {
    id = "notvisible"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      #  unit        = "Count"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_up" {
  count = "${
    var.queue_up_threshold > 0
    ? 1 : 0}"

  # Requires ECS ContainerInsights to be enabled: aws ecs update-cluster-settings --cluster <cluster name> --settings name=containerInsights,value=enabled
  # ECS cluster name and service name

  alarm_name          = "${module.label.id}-sqs-queuetime-up"
  alarm_description   = "Alarm monitors ${var.queue_name} QueueTime = ((Queue Size * Worker Timing) / (number of current tasks * Number Of workers per task))"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "${var.queue_up_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_queuetime_up.arn}"]
  metric_query {
    id          = "queuetime"
    expression  = "((visible) * ${var.queue_worker_timing}) / (IF(taskcount==0, 1, taskcount) * ${var.queue_task_worker_count})"
    label       = "WaitTime"
    return_data = "true"
  }
  metric_query {
    id = "visible"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
/*
  metric_query {
    id = "notvisible"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
*/
  metric_query {
    id = "taskcount"

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        ClusterName = "${var.cluster_name}"
        ServiceName = "${var.service_name}"
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_down" {
  count = "${
    var.queue_down_threshold > 0
    ? 1 : 0}"

  # Requires ECS ContainerInsights to be enabled: aws ecs update-cluster-settings --cluster <cluster name> --settings name=containerInsights,value=enabled
  # ECS cluster name and service name

  alarm_name          = "${module.label.id}-sqs-queuetime-down"
  alarm_description   = "Alarm monitors ${var.queue_name} QueueTime = ((Queue Size * Worker Timing) / (number of current tasks * Number Of workers per task))"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "${var.queue_down_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_queuetime_down.arn}"]
  metric_query {
    id          = "queuetime"
    expression  = "((visible) * ${var.queue_worker_timing}) / (IF(taskcount==0, 1, taskcount) * ${var.queue_task_worker_count})"
    label       = "WaitTime"
    return_data = "true"
  }
  metric_query {
    id = "visible"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
/*
  metric_query {
    id = "notvisible"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        QueueName = "${var.queue_name}"
      }
    }
  }
*/
  metric_query {
    id = "taskcount"

    metric {
      metric_name = "RunningTaskCount"
      namespace   = "ECS/ContainerInsights"
      period      = "60"
      stat        = "Maximum"

      dimensions {
        ClusterName = "${var.cluster_name}"
        ServiceName = "${var.service_name}"
      }
    }
  }
}
