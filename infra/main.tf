provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "ghost_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Public Subnets
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.ghost_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.ghost_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true  
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.ghost_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ghost_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_rta_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_1b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for EC2
resource "aws_security_group" "ghost_sg" {
  name   = "ghost-sg"
  vpc_id = aws_vpc.ghost_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # cidr_blocks = [var.allowed_ssh_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_key_pair" "ghost_key" {
  key_name   = "${var.ssh_key_name}-${random_id.suffix.hex}"
  public_key = tls_private_key.ghost_key.public_key_openssh
}

resource "tls_private_key" "ghost_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "local_file" "private_key" {
  content  = tls_private_key.ghost_key.private_key_pem
  filename = "my-aws-key.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "ghost" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.ghost_sg.id]
  key_name                    = aws_key_pair.ghost_key.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io curl
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              docker run -d \
                --name ghost \
                -p 80:2368 \
                -e url=http://$PUBLIC_IP \
                -e database__client=mysql \
                -e database__connection__host=${aws_db_instance.ghost_db.address} \
                -e database__connection__user=${var.db_username} \
                -e database__connection__password=${var.db_password} \
                -e database__connection__database=ghost \
                ghost:latest
              EOF
}

# MySQL Database
resource "aws_db_instance" "ghost_db" {
  identifier             = "ghostdb"
  engine                 = "mysql"
  engine_version         = "8.0.35"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.ghost_db_subnet.name
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.ghost_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ghost_sg.id]
  }
}

resource "aws_db_subnet_group" "ghost_db_subnet" {
  name       = "ghost-db-subnet-${random_id.suffix.hex}"
  subnet_ids = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]
}