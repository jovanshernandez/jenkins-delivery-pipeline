# A single EC2 host reachable through SSM Session Manager instead of SSH:
# no key pair, no port 22, IMDSv2 only, encrypted gp3 root volume.

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "${var.name} ingress"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = {
    for pair in flatten([
      for rule in var.ingress : [
        for cidr in rule.cidr_blocks : { key = "${rule.port}-${cidr}", rule = rule, cidr = cidr }
      ]
    ]) : pair.key => pair
  }

  security_group_id = aws_security_group.this.id
  description       = each.value.rule.description
  ip_protocol       = "tcp"
  from_port         = each.value.rule.port
  to_port           = each.value.rule.port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound for package installs, SSM and ECR"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "this" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(concat(["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"], var.managed_policy_arns))

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name   = "${var.name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-profile"
  role = aws_iam_role.this.name
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name
  user_data              = var.user_data
  monitoring             = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # containers on the host can still reach IMDSv2
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = var.name
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "this" {
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = {
    Name = var.name
  }
}
