output "instance_id" {
  description = "Jenkins controller instance ID. Connect with: aws ssm start-session --target <id>"
  value       = module.controller.instance_id
}

output "public_ip" {
  description = "Jenkins controller Elastic IP."
  value       = module.controller.public_ip
}

output "ecr_repository_url" {
  description = "Registry path the pipeline pushes delivery-app images to."
  value       = aws_ecr_repository.app.repository_url
}

output "ssm_transfer_bucket" {
  description = "Bucket the Ansible aws_ssm connection uses for file transfer (SSM_BUCKET)."
  value       = aws_s3_bucket.ssm_transfer.bucket
}
