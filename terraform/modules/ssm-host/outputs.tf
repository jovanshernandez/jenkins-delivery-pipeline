output "instance_id" {
  description = "EC2 instance ID (the target for SSM sessions and the Ansible inventory)."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP address."
  value       = aws_eip.this.public_ip
}

output "security_group_id" {
  description = "Security group attached to the instance."
  value       = aws_security_group.this.id
}

output "role_name" {
  description = "Instance IAM role name."
  value       = aws_iam_role.this.name
}

# Posture outputs: what the stacks' terraform tests assert against.

output "imds_http_tokens" {
  description = "IMDS token setting (\"required\" means IMDSv2 only)."
  value       = aws_instance.this.metadata_options[0].http_tokens
}

output "root_volume_encrypted" {
  description = "Whether the root volume is encrypted."
  value       = aws_instance.this.root_block_device[0].encrypted
}

output "ingress_rule_ports" {
  description = "Ports opened by ingress rules, one entry per rule."
  value       = [for key in sort(keys(aws_vpc_security_group_ingress_rule.this)) : aws_vpc_security_group_ingress_rule.this[key].from_port]
}

output "managed_policy_arns" {
  description = "Managed policies attached to the instance role."
  value       = sort(keys(aws_iam_role_policy_attachment.managed))
}
