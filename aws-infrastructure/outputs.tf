output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.research_vpc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private_subnet.id
}

output "k8s_control_plane_public_ip" {
  description = "Kubernetes control plane public IP"
  value       = aws_instance.k8s_control_plane.public_ip
}

output "k8s_control_plane_private_ip" {
  description = "Kubernetes control plane private IP"
  value       = aws_instance.k8s_control_plane.private_ip
}

output "k8s_worker_public_ips" {
  description = "Kubernetes worker nodes public IPs"
  value       = aws_instance.k8s_worker[*].public_ip
}

output "k8s_worker_private_ips" {
  description = "Kubernetes worker nodes private IPs"
  value       = aws_instance.k8s_worker[*].private_ip
}

output "docker_manager_public_ip" {
  description = "Docker Swarm manager public IP"
  value       = aws_instance.docker_manager.public_ip
}

output "docker_manager_private_ip" {
  description = "Docker Swarm manager private IP"
  value       = aws_instance.docker_manager.private_ip
}

output "docker_worker_public_ips" {
  description = "Docker Swarm worker nodes public IPs"
  value       = aws_instance.docker_worker[*].public_ip
}

output "docker_worker_private_ips" {
  description = "Docker Swarm worker nodes private IPs"
  value       = aws_instance.docker_worker[*].private_ip
}

output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = aws_iam_role.karpenter_controller_role.arn
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "ssh_command_k8s_control_plane" {
  description = "SSH command to connect to Kubernetes control plane"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.k8s_control_plane.public_ip}"
}

output "ssh_command_docker_manager" {
  description = "SSH command to connect to Docker Swarm manager"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.docker_manager.public_ip}"
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = "https://${aws_instance.k8s_control_plane.public_ip}:6443"
}

# Instance IDs for automation scripts
output "k8s_control_plane_id" {
  description = "Kubernetes control plane instance ID"
  value       = aws_instance.k8s_control_plane.id
}

output "k8s_worker_1_id" {
  description = "Kubernetes worker 1 instance ID"
  value       = aws_instance.k8s_worker[0].id
}

output "k8s_worker_2_id" {
  description = "Kubernetes worker 2 instance ID"
  value       = aws_instance.k8s_worker[1].id
}

output "k8s_worker_1_public_ip" {
  description = "Kubernetes worker 1 public IP"
  value       = aws_instance.k8s_worker[0].public_ip
}

output "k8s_worker_2_public_ip" {
  description = "Kubernetes worker 2 public IP"
  value       = aws_instance.k8s_worker[1].public_ip
}

output "docker_manager_id" {
  description = "Docker Swarm manager instance ID"
  value       = aws_instance.docker_manager.id
}

output "docker_worker_1_id" {
  description = "Docker Swarm worker 1 instance ID"
  value       = aws_instance.docker_worker[0].id
}

output "docker_worker_2_id" {
  description = "Docker Swarm worker 2 instance ID"
  value       = aws_instance.docker_worker[1].id
}

output "docker_worker_1_public_ip" {
  description = "Docker Swarm worker 1 public IP"
  value       = aws_instance.docker_worker[0].public_ip
}

output "docker_worker_2_public_ip" {
  description = "Docker Swarm worker 2 public IP"
  value       = aws_instance.docker_worker[1].public_ip
}