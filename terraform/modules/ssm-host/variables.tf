variable "name" {
  description = "Name prefix for the instance, security group, IAM role and instance profile."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.name))
    error_message = "name must be 3-41 characters of lowercase letters, digits and hyphens."
  }
}

variable "ami_id" {
  description = "AMI to launch. Must be an ARM64 image to match the Graviton instance types."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must look like ami-0123456789abcdef0."
  }
}

variable "instance_type" {
  description = "Graviton (ARM64) instance type."
  type        = string

  validation {
    condition     = can(regex("^(t4g|m7g|m8g|c7g|c8g|r7g|r8g)\\.", var.instance_type))
    error_message = "instance_type must be a Graviton (ARM64) type such as t4g.small."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 200
    error_message = "root_volume_size must be between 8 and 200 GiB."
  }
}

variable "vpc_id" {
  description = "VPC for the security group. Null uses the default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet for the instance. Null lets EC2 pick a default subnet."
  type        = string
  default     = null
}

variable "ingress" {
  description = "TCP ports to open and the CIDR blocks allowed to reach each. No SSH: access is through SSM Session Manager."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for rule in var.ingress : rule.port != 22])
    error_message = "Port 22 is not allowed. Use SSM Session Manager for shell access."
  }

  validation {
    condition     = alltrue(flatten([for rule in var.ingress : [for cidr in rule.cidr_blocks : can(cidrnetmask(cidr))]]))
    error_message = "Every ingress cidr_blocks entry must be a valid IPv4 CIDR."
  }
}

variable "managed_policy_arns" {
  description = "Extra AWS managed policies for the instance role (SSM core is always attached)."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline IAM policy document for the instance role."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Optional cloud-init user data."
  type        = string
  default     = null
}
