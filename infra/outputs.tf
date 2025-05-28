output "ec2_public_ip" {
  description = "Public IP address of the Ghost CMS EC2 instance"
  value       = aws_instance.ghost.public_ip
}

output "rds_endpoint" {
  description = "Endpoint of the RDS MySQL database"
  value       = aws_db_instance.ghost_db.endpoint
}

output "ghost_url" {
  description = "URL to access Ghost CMS"
  value       = "http://${aws_instance.ghost.public_ip}"
}