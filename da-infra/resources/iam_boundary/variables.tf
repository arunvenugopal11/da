variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-southeast-1"
}
