variable "github_repo" {
  description = "GitHub repository in 'owner/repo' format allowed to assume this role"
  type        = string
}

variable "account_id" {
  description = "AWS account ID — used to scope IAM resource ARNs"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}
