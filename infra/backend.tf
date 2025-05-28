terraform {
  backend "s3" {
    bucket         = "ghost-terraform-state-bucket-devsec"
    key            = "ghost/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ghost-terraform-locks"
  }
}