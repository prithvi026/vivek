variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "phd-k8s-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t2.micro"
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for control plane"
  type        = string
  default     = "t3.medium"
}

variable "docker_manager_instance_type" {
  description = "EC2 instance type for Docker Swarm manager"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "phd-research-key"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "research"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "k8s-docker-comparison"
}