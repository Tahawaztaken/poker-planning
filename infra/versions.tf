terraform {
  # Terraform 1.6+ gives us stable lifecycle/precondition behavior and modern
  # provider lock-file handling. Newer versions should also work.
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Recommended for real use:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "scrum-tool/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region # AWS region where Terraform creates resources.

  default_tags {
    tags = local.common_tags # Applies common tags to supported AWS resources.
  }
}
