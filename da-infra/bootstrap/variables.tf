variable "aws_region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id" {
  description = "AWS account ID — used to ensure globally unique bucket name"
  type        = string
}
