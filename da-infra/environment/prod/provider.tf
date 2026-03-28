terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    region         = "ap-southeast-1"
    bucket         = "da-tfstate-REPLACE_WITH_ACCOUNT_ID"
    key            = "da/prod/terraform.tfstate"
    dynamodb_table = "da-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      application_name       = "Da prod"
      deployment_environment = "prod"
      deployment_source      = "terraform"
      git_repo_id            = "https://github.com/YOUR_ORG/da-infra"
      team                   = "engineering"
      project                = "da"
    }
  }
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  default_tags {
    tags = {
      application_name       = "Da prod"
      deployment_environment = "prod"
      deployment_source      = "terraform"
    }
  }
}
