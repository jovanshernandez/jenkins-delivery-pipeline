variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be an AWS region name such as us-east-1."
  }
}

variable "aws_profile" {
  description = "AWS CLI profile. Null uses the default credential chain (environment variables in Jenkins)."
  type        = string
  default     = null
}

variable "project" {
  description = "Project name, used as the resource name prefix and the App tag."
  type        = string
  default     = "jenkins-delivery-pipeline"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project))
    error_message = "project must be 3-31 characters of lowercase letters, digits and hyphens."
  }
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter that resolves to the AMI (Amazon Linux 2023, ARM64 by default)."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "Instance type for the web host (Graviton)."
  type        = string
  default     = "t4g.small"

  validation {
    condition     = can(regex("^(t4g|m7g|m8g|c7g|c8g|r7g|r8g)\\.", var.instance_type))
    error_message = "instance_type must be a Graviton (ARM64) type to match the ARM64 AMI."
  }
}

variable "app_port" {
  description = "Port the delivery-app container listens on."
  type        = number
  default     = 8000

  validation {
    condition     = var.app_port > 1024 && var.app_port < 65536 && var.app_port != 8080
    error_message = "app_port must be an unprivileged port (1025-65535) other than 8080."
  }
}

variable "app_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the app port. Empty means SSM port forwarding only."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.app_ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "app_ingress_cidrs must be valid IPv4 CIDRs."
  }
}
