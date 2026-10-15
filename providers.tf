terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "lab"
      ManagedBy   = "Terraform"
      Course      = "Services and Development Platforms for Cloud Based Applications"
      University  = "WSB Merito Wroclaw"
      Lab         = "Lab 10 - AWS Lambda"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}
