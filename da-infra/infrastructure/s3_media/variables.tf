variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "upload_role_arns" {
  description = "IAM role ARNs allowed to upload to the media bucket (Lambda roles)"
  type        = list(string)
  default     = []
}
