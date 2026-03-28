variable "aws_region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID — used to ensure globally unique bucket name"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username (e.g. arunvenugopal11)"
  type        = string
  default     = "arunvenugopal11"
}

variable "github_repo" {
  description = "GitHub repository name (e.g. da)"
  type        = string
  default     = "da"
}
