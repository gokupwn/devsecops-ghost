variable "db_username" {
  description = "Username for the RDS MySQL database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS MySQL database"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
  default     = "ghost-key"
}

variable "allowed_ssh_ip" {
  description = "IP address allowed to SSH into the EC2 instance"
  type        = string
  default     = "0.0.0.0/0"
}