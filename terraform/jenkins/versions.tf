terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration: supply bucket, key and region with
  #   terraform init -backend-config=backend.hcl
  # (see backend.hcl.example). CI validates with -backend=false.
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = merge(var.tags, {
      App       = var.project
      Component = "jenkins"
      ManagedBy = "terraform"
    })
  }
}
