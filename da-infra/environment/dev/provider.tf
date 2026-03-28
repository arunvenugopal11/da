terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Remote state — created by bootstrap/ before running this
  backend "s3" {
    region         = "ap-southeast-1"
    bucket         = "da-tfstate-REPLACE_WITH_ACCOUNT_ID"
    key            = "da/dev/terraform.tfstate"
    dynamodb_table = "da-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      application_name       = "Da dev"
      deployment_environment = "dev"
      deployment_source      = "terraform"
      git_repo_id            = "https://github.com/YOUR_ORG/da-infra"
      team                   = "engineering"
      project                = "da"
    }
  }
}

# Virginia provider — for CloudFront ACM certificates (must be us-east-1)
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  default_tags {
    tags = {
      application_name       = "Da dev"
      deployment_environment = "dev"
      deployment_source      = "terraform"
    }
  }
}
