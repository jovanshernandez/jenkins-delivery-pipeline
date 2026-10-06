# Jenkins controller plus the artifacts it publishes: an ECR repository for
# delivery-app images and a private bucket the Ansible SSM connection uses for
# file transfer.

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter
}

resource "aws_ecr_repository" "app" {
  name                 = "delivery-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = { type = "expire" }
      },
    ]
  })
}

resource "aws_s3_bucket" "ssm_transfer" {
  bucket        = "${var.project}-ssm-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ssm_transfer" {
  bucket                  = aws_s3_bucket.ssm_transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  rule {
    id     = "expire-transfers"
    status = "Enabled"
    filter {}
    expiration {
      days = 1
    }
  }
}

module "controller" {
  source = "../modules/ssm-host"

  name             = "${var.project}-jenkins"
  ami_id           = data.aws_ssm_parameter.ami.insecure_value
  instance_type    = var.instance_type
  root_volume_size = 40

  ingress = length(var.ui_ingress_cidrs) == 0 ? [] : [{
    description = "Jenkins UI"
    port        = 8080
    cidr_blocks = var.ui_ingress_cidrs
  }]

  # The controller builds and pushes images; it never needs more than this repository.
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPushDeliveryApp"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}
