variable "name" {
  description = "Short identifier used in resource names (e.g. 'gateway' or 'backend')"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to use (exactly 2 expected)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets used by NAT gateways (one per AZ)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name — used to apply required Kubernetes subnet discovery tags"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}
