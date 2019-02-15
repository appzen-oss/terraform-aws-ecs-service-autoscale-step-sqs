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

##
## Autoscaling IAM
##
resource "aws_iam_role" "ecs_service_autoscale" {
  name = "${var.service_name}-ecs-service-autoscale"

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
  name               = "${var.service_name}-scale-up-queue"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                = 60
    adjustment_type         = "ChangeInCapacity"
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = "${var.scale_up_count}"
    }
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  depends_on         = ["aws_appautoscaling_target.target"]
  name               = "${var.service_name}-scale-down-queue"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  step_scaling_policy_configuration = {
    cooldown                = 60
    adjustment_type         = "ChangeInCapacity"
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = "${var.scale_down_count}"
    }
  }
}

##
## Cloudwatch Alarms
##
resource "aws_cloudwatch_metric_alarm" "service_queue_high" {
  alarm_name          = "${var.service_name}-queue-count-high"
  alarm_description   = "This alarm monitors ${var.service_name} Queue count utilization for scaling up"
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
  alarm_name          = "${var.service_name}-queue-count-low"
  alarm_description   = "This alarm monitors ${var.service_name} Queue count utilization for scaling down"
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
