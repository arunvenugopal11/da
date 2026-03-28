variable "env_name" {
  description = "Environment name (dev | prod)"
  type        = string
}

variable "boundary_policy_arn" {
  description = "IAM permission boundary ARN"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — from common module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS — from common module"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS security group ID — from common module"
  type        = string
}

variable "lambda_execution_role_arns" {
  description = "Lambda role ARNs that connect via RDS Proxy IAM auth"
  type        = list(string)
  default     = []
}

variable "db_password" {
  description = "RDS master password — sourced from HCP Vault via CI/CD"
  type        = string
  sensitive   = true
}

# Instance size varies by environment
variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro" # dev default — prod overrides to db.t4g.small
}

variable "multi_az" {
  description = "Enable Multi-AZ (prod only — doubles cost)"
  type        = bool
  default     = false
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}
