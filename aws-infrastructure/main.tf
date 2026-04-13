terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC for the research environment
resource "aws_vpc" "research_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "phd-research-vpc"
    Project     = "k8s-docker-comparison"
    Environment = "research"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "research_igw" {
  vpc_id = aws_vpc.research_vpc.id

  tags = {
    Name    = "phd-research-igw"
    Project = "k8s-docker-comparison"
  }
}

# Public subnet for control plane and managers
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.research_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                        = "phd-public-subnet"
    Project                     = "k8s-docker-comparison"
    "kubernetes.io/role/elb"    = "1"
    "karpenter.sh/discovery"    = "phd-k8s-cluster"
  }
}

# Private subnet for worker nodes
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.research_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = "phd-private-subnet"
    Project                           = "k8s-docker-comparison"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "phd-k8s-cluster"
  }
}

# Route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.research_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.research_igw.id
  }

  tags = {
    Name    = "phd-public-rt"
    Project = "k8s-docker-comparison"
  }
}

# Associate public subnet with route table
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway for private subnet internet access
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name    = "phd-nat-eip"
    Project = "k8s-docker-comparison"
  }
}

resource "aws_nat_gateway" "research_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name    = "phd-research-nat"
    Project = "k8s-docker-comparison"
  }

  depends_on = [aws_internet_gateway.research_igw]
}

# Route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.research_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.research_nat.id
  }

  tags = {
    Name    = "phd-private-rt"
    Project = "k8s-docker-comparison"
  }
}

# Associate private subnet with route table
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security group for Kubernetes control plane
resource "aws_security_group" "k8s_control_plane_sg" {
  name        = "phd-k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.research_vpc.id

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # etcd server client API
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flask app port
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "phd-k8s-control-plane-sg"
    Project = "k8s-docker-comparison"
  }
}

# Security group for worker nodes
resource "aws_security_group" "worker_nodes_sg" {
  name        = "phd-worker-nodes-sg"
  description = "Security group for worker nodes"
  vpc_id      = aws_vpc.research_vpc.id

  # All traffic from control plane
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.k8s_control_plane_sg.id]
  }

  # Inter-worker communication
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flask app port
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker Swarm ports
  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "phd-worker-nodes-sg"
    Project = "k8s-docker-comparison"
  }
}

# Key pair for EC2 instances
resource "aws_key_pair" "research_key" {
  key_name   = "phd-research-key"
  public_key = file("~/.ssh/id_rsa.pub")

  tags = {
    Name    = "phd-research-key"
    Project = "k8s-docker-comparison"
  }
}

# IAM role for Karpenter
resource "aws_iam_role" "karpenter_controller_role" {
  name = "KarpenterControllerIAMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name    = "KarpenterControllerIAMRole"
    Project = "k8s-docker-comparison"
  }
}

# IAM policy for Karpenter
resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "KarpenterControllerIAMPolicy"
  description = "IAM policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypeOfferings",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "KarpenterControllerIAMPolicy"
    Project = "k8s-docker-comparison"
  }
}

# Attach policy to Karpenter role
resource "aws_iam_role_policy_attachment" "karpenter_controller_policy_attachment" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# Instance profile for Karpenter
resource "aws_iam_instance_profile" "karpenter_controller_instance_profile" {
  name = "KarpenterControllerIAMInstanceProfile"
  role = aws_iam_role.karpenter_controller_role.name

  tags = {
    Name    = "KarpenterControllerIAMInstanceProfile"
    Project = "k8s-docker-comparison"
  }
}

# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Kubernetes control plane instance
resource "aws_instance" "k8s_control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  key_name              = aws_key_pair.research_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_control_plane_sg.id]
  subnet_id             = aws_subnet.public_subnet.id
  iam_instance_profile  = aws_iam_instance_profile.karpenter_controller_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data/k8s_control_plane.sh", {
    cluster_name = var.cluster_name
  }))

  tags = {
    Name                                        = "phd-k8s-control-plane"
    Project                                     = var.project_name
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

# Kubernetes worker nodes
resource "aws_instance" "k8s_worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.node_instance_type
  key_name              = aws_key_pair.research_key.key_name
  vpc_security_group_ids = [aws_security_group.worker_nodes_sg.id]
  subnet_id             = aws_subnet.public_subnet.id

  root_block_device {
    volume_type = "gp3"
    volume_size = 15
    encrypted   = true
  }

  user_data = base64encode(file("${path.module}/user_data/k8s_worker.sh"))

  tags = {
    Name                                        = "phd-k8s-worker-${count.index + 1}"
    Project                                     = var.project_name
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "karpenter.sh/discovery"                    = var.cluster_name
    "node-type"                                 = "karpenter-managed"
  }
}

# Docker Swarm manager node
resource "aws_instance" "docker_manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.docker_manager_instance_type
  key_name              = aws_key_pair.research_key.key_name
  vpc_security_group_ids = [aws_security_group.worker_nodes_sg.id]
  subnet_id             = aws_subnet.public_subnet.id

  root_block_device {
    volume_type = "gp3"
    volume_size = 15
    encrypted   = true
  }

  user_data = base64encode(file("${path.module}/user_data/docker_manager.sh"))

  tags = {
    Name        = "phd-docker-manager"
    Project     = var.project_name
    Environment = var.environment
    Role        = "docker-swarm-manager"
  }
}

# Docker Swarm worker nodes
resource "aws_instance" "docker_worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.node_instance_type
  key_name              = aws_key_pair.research_key.key_name
  vpc_security_group_ids = [aws_security_group.worker_nodes_sg.id]
  subnet_id             = aws_subnet.public_subnet.id

  root_block_device {
    volume_type = "gp3"
    volume_size = 15
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data/docker_worker.sh", {
    manager_ip = aws_instance.docker_manager.private_ip
  }))

  tags = {
    Name        = "phd-docker-worker-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    Role        = "docker-swarm-worker"
  }

  depends_on = [aws_instance.docker_manager]
}
