variable "adjustment_type_down" {
  description = "Autoscaling policy down adjustment type (ChangeInCapacity, PercentChangeInCapacity)"
  default     = "ExactCapacity"
}

variable "adjustment_type_up" {
  description = "Autoscaling policy up adjustment type (ChangeInCapacity, PercentChangeInCapacity)"
  default     = "ChangeInCapacity"
}

variable "cluster_name" {
  description = "Name of ECS cluster that service is in"
}

variable "queue_name" {
  description = "Name of SQS queue to monitor"
}

variable "service_name" {
  description = "Name of ECS service to autoscale"
}

variable "high_eval_periods" {
  description = "The number of periods over which data is compared to the high threshold"
  default     = "1"
}

variable "high_period_secs" {
  description = "The period in seconds over which the high statistic is applied"
  default     = "60"
}

variable "high_threshold" {
  description = "The value against which the high statistic is compared"
  default     = "1000"
}

variable "high_big_threshold" {
  description = "The value against which the high statistic is compared"
  default     = "0"
}

variable "scale_big_up_count" {
  description = "The value against which the high statistic is compared"
  default     = "20"
}

variable "scale_big_up_cooldown" {
  description = "The value against which the high statistic is compared"
  default     = "600"
}

variable "low_eval_periods" {
  description = "The number of periods over which data is compared to the low threshold"
  default     = "1"
}

variable "low_period_secs" {
  description = "The period in seconds over which the low statistic is applied"
  default     = "60"
}

variable "low_threshold" {
  description = "The value against which the low statistic is compared"
  default     = "100"
}

variable "max_capacity" {
  description = "Maximum number of tasks to scale to"
  default     = "5"
}

variable "min_capacity" {
  description = "Minimum number of tasks to scale to"
  default     = "0"
}

variable "scale_down_cooldown" {
  description = "The amount of time, in seconds, after a scaling down completes and before the next scaling activity can start"
  default     = "60"
}

variable "scale_down_count" {
  description = "The number of members by which to scale down, when the adjustment bounds are breached. Should always be negative value"
  default     = "-3"
}

variable "scale_down_lower_bound" {
  description = "The lower bound for the difference between the alarm threshold and the CloudWatch metric. Without a value, AWS will treat this bound as negative infinity"
  default     = ""
}

variable "scale_down_upper_bound" {
  description = "The upper bound for the difference between the alarm threshold and the CloudWatch metric. Without a value, AWS will treat this bound as infinity"
  default     = "0"
}

variable "scale_down_min_adjustment_magnitude" {
  description = "Minimum number of tasks to scale down at a time "
  default     = "0"
}

variable "scale_up_cooldown" {
  description = "The amount of time, in seconds, after a scaling up completes and before the next scaling up can start"
  default     = "60"
}

variable "scale_up_count" {
  description = "The number of members by which to scale up, when the adjustment bounds are breached. Should always be positive value"
  default     = "5"
}

variable "scale_up_lower_bound" {
  description = "The lower bound for the difference between the alarm threshold and the CloudWatch metric. Without a value, AWS will treat this bound as negative infinity"
  default     = "0"
}

variable "scale_up_upper_bound" {
  description = "The upper bound for the difference between the alarm threshold and the CloudWatch metric. Without a value, AWS will treat this bound as infinity"
  default     = ""
}

variable "scale_up_min_adjustment_magnitude" {
  description = "Minimum number of tasks to scale up at a time "
  default     = "0"
}
