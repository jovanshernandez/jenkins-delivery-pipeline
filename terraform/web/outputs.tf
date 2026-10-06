output "instance_id" {
  description = "Web host instance ID. Connect with: aws ssm start-session --target <id>"
  value       = module.web.instance_id
}

output "public_ip" {
  description = "Web host Elastic IP."
  value       = module.web.public_ip
}

output "app_url" {
  description = "delivery-app URL (reachable only from app_ingress_cidrs)."
  value       = "http://${module.web.public_ip}:${var.app_port}"
}
