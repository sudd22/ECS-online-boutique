terraform {
  required_version = ">=1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "b2b-monolith"
      ManagedBy   = "terraform"
    }
  }
}
