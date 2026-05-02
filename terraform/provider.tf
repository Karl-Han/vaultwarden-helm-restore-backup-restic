terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

provider "aws" {
  region = var.us_east_1_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "vaultwarden"
    }
  }
}

provider "aws" {
  alias  = "us_east_2"
  region = var.us_east_2_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "vaultwarden"
    }
  }
}
