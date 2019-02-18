variable "attributes" {
  description = "Suffix name with additional attributes (policy, role, etc.)"
  type        = "list"
  default     = []
}

variable "component" {
  description = "TAG: Underlying, dedicated piece of service (Cache, DB, ...)"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}

variable "delimiter" {
  description = "Delimiter to be used between `name`, `namespaces`, `attributes`, etc."
  type        = "string"
  default     = "-"
}

variable "environment" {
  description = "Environment (ex: `dev`, `qa`, `stage`, `prod`). (Second or top level namespace. Depending on namespacing options)"
  type        = "string"
}

variable "monitor" {
  description = "TAG: Should resource be monitored"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}

variable "name" {
  description = "Base name for resource"
  type        = "string"
}

variable "namespace-env" {
  description = "Prefix name with the environment. If true, format is: `{env}-{name}`"
  default     = true
}

variable "namespace-org" {
  description = "Prefix name with the organization. If true, format is: `{org}-{env namespaced name}`. If both env and org namespaces are used, format will be `{org}-{env}-{name}`"
  default     = false
}

variable "organization" {
  description = "Organization name (Top level namespace)"
  type        = "string"
  default     = ""
}

variable "owner" {
  description = "TAG: Owner of the service"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}

variable "product" {
  description = "TAG: Company/business product"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}

variable "service" {
  description = "TAG: Application (microservice) name"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}

variable "tags" {
  description = "A map of additional tags"
  type        = "map"
  default     = {}
}

variable "team" {
  description = "TAG: Department/team of people responsible for service"
  type        = "string"
  default     = "UNDEF-ECSAutoScaleSQS"
}
