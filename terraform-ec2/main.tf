provider "aws" {
  region = var.aws_region
}

# Generate private key
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create key pair in AWS
resource "aws_key_pair" "indexer_key" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "${path.module}/${var.key_pair_name}.pem"
  file_permission = "0400"
}

# Security Group
resource "aws_security_group" "indexer_sg" {
  name        = "indexer_sg"
  description = "Allow SSH, HTTP, HTTPS and Custom TCP range"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 9999
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
    Name = "indexer_sg"
  }
}

# Get latest RHEL 9 AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # RedHat official account

  filter {
    name   = "name"
    values = ["RHEL-9.3.0_HVM-*-x86_64-*Hourly2-GP2"] # tested working name format
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets in specific AZs to avoid unsupported instance error
data "aws_subnets" "filtered" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"]
  }
}

# Launch EC2 Instances
resource "aws_instance" "indexer" {
  count         = 17
  ami           = data.aws_ami.redhat.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.indexer_key.key_name
  subnet_id     = element(data.aws_subnets.filtered.ids, count.index % length(data.aws_subnets.filtered.ids))
  security_groups = [aws_security_group.indexer_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "Indexer-${count.index + 1}"
  }
}
