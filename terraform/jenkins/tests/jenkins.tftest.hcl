# Plan-only tests against a mocked AWS provider: no credentials, no API calls.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "controller_is_locked_down_by_default" {
  command = plan

  assert {
    condition     = length(module.controller.ingress_rule_ports) == 0
    error_message = "no ingress should be opened unless ui_ingress_cidrs is set"
  }

  assert {
    condition     = module.controller.imds_http_tokens == "required"
    error_message = "IMDSv2 must be required"
  }

  assert {
    condition     = module.controller.root_volume_encrypted
    error_message = "root volume must be encrypted"
  }
}

run "ui_ingress_is_opt_in" {
  command = plan

  variables {
    ui_ingress_cidrs = ["203.0.113.10/32"]
  }

  assert {
    condition     = module.controller.ingress_rule_ports == [8080]
    error_message = "only the Jenkins UI port should be opened"
  }
}

run "ecr_and_transfer_bucket" {
  command = plan

  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE"
    error_message = "image tags must be immutable so a deployed tag always means the same image"
  }

  assert {
    condition     = aws_s3_bucket.ssm_transfer.bucket == "jenkins-delivery-pipeline-ssm-123456789012"
    error_message = "transfer bucket name should be project + account id"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.ssm_transfer.restrict_public_buckets
    error_message = "transfer bucket must block public access"
  }
}

run "rejects_world_open_ui" {
  command = plan

  variables {
    ui_ingress_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ui_ingress_cidrs]
}

run "rejects_x86_instance_type" {
  command = plan

  variables {
    instance_type = "t3.medium"
  }

  expect_failures = [var.instance_type]
}
