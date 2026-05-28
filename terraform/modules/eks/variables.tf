variable "cluster_name" {
  description = "EKS cluster name (must begin with 'eks-' per role naming policy)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC to place the cluster in"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for node placement and control-plane ENIs"
  type        = list(string)
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum node count"
  type        = number
  default     = 3
}

variable "extra_ingress_cidr_blocks" {
  description = "Additional CIDRs allowed to reach nodes on port 80 (e.g. peered VPC CIDR for backend)"
  type        = list(string)
  default     = []
}

variable "extra_egress_cidr_blocks" {
  description = "Additional CIDRs nodes can reach (not currently used — egress is open by default)"
  type        = list(string)
  default     = []
}
