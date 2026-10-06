# Web host that runs the delivery-app container. Ansible (provision_web.yaml)
# installs Docker and the systemd unit; the instance role can only pull images.

data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter
}

module "web" {
  source = "../modules/ssm-host"

  name             = "${var.project}-web"
  ami_id           = data.aws_ssm_parameter.ami.insecure_value
  instance_type    = var.instance_type
  root_volume_size = 20

  ingress = length(var.app_ingress_cidrs) == 0 ? [] : [{
    description = "delivery-app HTTP"
    port        = var.app_port
    cidr_blocks = var.app_ingress_cidrs
  }]

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]
}
