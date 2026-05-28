variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment label applied to all resources"
  type        = string
  default     = "poc"
}

variable "gateway_vpc_cidr" {
  description = "CIDR block for the public-facing gateway VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "backend_vpc_cidr" {
  description = "CIDR block for the private backend VPC (must not overlap with gateway)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the OIDC role (format: owner/repo)"
  type        = string
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS managed node groups"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "Desired node count per cluster"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum node count per cluster"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum node count per cluster"
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "Kubernetes version for both EKS clusters"
  type        = string
  default     = "1.29"
}
