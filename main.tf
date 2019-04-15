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
  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-scale-up-queue"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_up_cooldown}"
    adjustment_type          = "${var.adjustment_type}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_up_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_up_lower_bound}"
      scaling_adjustment          = "${var.scale_up_count}"
    }
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${module.label.id}-scale-down-queue"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                 = "${var.scale_down_cooldown}"
    adjustment_type          = "${var.adjustment_type}"
    metric_aggregation_type  = "Average"
    min_adjustment_magnitude = "${var.scale_down_min_adjustment_magnitude}"

    step_adjustment {
      metric_interval_lower_bound = "${var.scale_down_lower_bound}"
      scaling_adjustment          = "${var.scale_down_count}"
    }
  }
}

##
## Cloudwatch Alarms
##
resource "aws_cloudwatch_metric_alarm" "service_queue_high" {
  alarm_name          = "${module.label.id}-queue-count-high"
  alarm_description   = "This alarm monitors ${var.queue_name} Queue count utilization for scaling up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.high_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_up.arn}"]

  dimensions {
    QueueName = "${var.queue_name}"
  }
}

# A CloudWatch alarm that monitors CPU utilization of containers for scaling down
resource "aws_cloudwatch_metric_alarm" "service_queue_low" {
  alarm_name          = "${module.label.id}-queue-count-low"
  alarm_description   = "This alarm monitors ${var.queue_name} Queue count utilization for scaling down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "${var.low_threshold}"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_down.arn}"]

  dimensions {
    QueueName = "${var.queue_name}"
  }
}
