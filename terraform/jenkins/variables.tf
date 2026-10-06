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
  description = "Instance type for the Jenkins controller (Graviton)."
  type        = string
  default     = "t4g.medium"

  validation {
    condition     = can(regex("^(t4g|m7g|m8g|c7g|c8g|r7g|r8g)\\.", var.instance_type))
    error_message = "instance_type must be a Graviton (ARM64) type to match the ARM64 AMI."
  }
}

variable "ui_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the Jenkins UI on 8080. Empty means SSM port forwarding only."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.ui_ingress_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "ui_ingress_cidrs must be valid IPv4 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "image_retention_count" {
  description = "How many tagged images to keep in the ECR repository."
  type        = number
  default     = 30

  validation {
    condition     = var.image_retention_count >= 5 && var.image_retention_count <= 1000
    error_message = "image_retention_count must be between 5 and 1000."
  }
}
