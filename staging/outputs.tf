output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.staging_alb.dns_name
}

output "server_public_ip" {
  description = "K3s server public IP address (Elastic IP)"
  value       = aws_eip.k3s_server.public_ip
}

output "server_instance_id" {
  description = "K3s server EC2 instance ID"
  value       = aws_instance.k3s_server.id
}

output "kubeconfig_command" {
  description = "Command to fetch kubeconfig using SSM"
  value       = "aws ssm send-command --instance-ids ${aws_instance.k3s_server.id} --document-name 'AWS-RunShellScript' --parameters 'commands=[\"cat /etc/rancher/k3s/k3s.yaml\"]'"
}
