provider "aws" {
  region = var.aws_region
}

# Generate SSH key pair
resource "tls_private_key" "bootstrap_k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key" {
  content  = tls_private_key.bootstrap_k8s_key.private_key_pem
  filename = "${path.module}/id_rsa"
}

resource "local_file" "ssh_public_key" {
  content  = tls_private_key.bootstrap_k8s_key.public_key_pem
  filename = "${path.module}/id_rsa.pub"
}

# Create AWS key pair
resource "aws_key_pair" "bootstrap_k8s_key_pair" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.bootstrap_k8s_key.public_key_openssh
}

# Get VPC
data "aws_vpc" "selected" {
  id = "vpc-026038abecbf503ed"
}

# Create security group
resource "aws_security_group" "bootstrap_k8s_sg" {
  name_prefix = "bootstrap_k8s-sg"
  vpc_id      = data.aws_vpc.selected.id

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.cidr_blocks
  }

  # Kubernetes-specific ports
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  # etcd ports
  ingress {
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 2380
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = var.cidr_blocks
  }

  # Network plugin ports
  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "udp"
    cidr_blocks = var.cidr_blocks
  }

  ingress {
    from_port   = 6784
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = var.cidr_blocks
  }
}

# Create master node
resource "aws_instance" "bootstrap_k8s_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  security_groups        = [aws_security_group.bootstrap_k8s_sg.name]
  key_name               = aws_key_pair.bootstrap_k8s_key_pair.key_name
  user_data              = templatefile("./master.sh", {
    s3bucket_name = var.bucket_name,
    region        = var.aws_region
  })
  iam_instance_profile = aws_iam_instance_profile.s3_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp2"
  }

  tags = {
    Name = "master"
  }
}

# Create worker nodes
resource "aws_instance" "bootstrap_k8s_worker" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = var.instance_type
  security_groups        = [aws_security_group.bootstrap_k8s_sg.name]
  key_name               = aws_key_pair.bootstrap_k8s_key_pair.key_name
  iam_instance_profile = aws_iam_instance_profile.s3_profile.name
  user_data              = templatefile("workers.sh", {
    s3bucket_name = var.bucket_name,
    worker_number = count.index
  })

  depends_on             = [aws_instance.bootstrap_k8s_master]

    root_block_device {
    volume_size           = 30
    volume_type           = "gp2"
  }

  tags = {
    Name = "worker-node${count.index + 1}"
  }
}