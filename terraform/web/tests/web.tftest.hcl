# Plan-only tests against a mocked AWS provider: no credentials, no API calls.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }
}

run "web_host_defaults" {
  command = plan

  assert {
    condition     = module.web.imds_http_tokens == "required"
    error_message = "IMDSv2 must be required"
  }

  assert {
    condition     = module.web.root_volume_encrypted
    error_message = "root volume must be encrypted"
  }

  assert {
    condition     = length(module.web.ingress_rule_ports) == 0
    error_message = "no ingress should be opened unless app_ingress_cidrs is set"
  }

  assert {
    condition     = contains(module.web.managed_policy_arns, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore")
    error_message = "the host must be reachable through SSM"
  }

  assert {
    condition     = contains(module.web.managed_policy_arns, "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly")
    error_message = "the host must be able to pull from ECR"
  }
}

run "app_port_opens_only_to_given_cidrs" {
  command = plan

  variables {
    app_ingress_cidrs = ["198.51.100.0/24", "203.0.113.10/32"]
  }

  assert {
    condition     = module.web.ingress_rule_ports == [8000, 8000]
    error_message = "one app-port rule per CIDR expected"
  }

  assert {
    condition     = output.app_url != null
    error_message = "app_url output should be set"
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    app_ingress_cidrs = ["not-a-cidr"]
  }

  expect_failures = [var.app_ingress_cidrs]
}

run "rejects_ssh_port" {
  command = plan

  variables {
    app_port          = 22
    app_ingress_cidrs = ["203.0.113.10/32"]
  }

  expect_failures = [var.app_port]
}
