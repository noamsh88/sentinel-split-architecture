output "vpc_gateway_id" {
  description = "ID of the gateway VPC"
  value       = module.vpc_gateway.vpc_id
}

output "vpc_backend_id" {
  description = "ID of the backend VPC"
  value       = module.vpc_backend.vpc_id
}

output "eks_gateway_cluster_name" {
  description = "Name of the gateway EKS cluster"
  value       = module.eks_gateway.cluster_name
}

output "eks_gateway_endpoint" {
  description = "API server endpoint for the gateway cluster"
  value       = module.eks_gateway.cluster_endpoint
}

output "eks_backend_cluster_name" {
  description = "Name of the backend EKS cluster"
  value       = module.eks_backend.cluster_name
}

output "eks_backend_endpoint" {
  description = "API server endpoint for the backend cluster"
  value       = module.eks_backend.cluster_endpoint
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
  value       = module.iam.github_actions_role_arn
}

output "vpc_peering_id" {
  description = "ID of the VPC peering connection"
  value       = module.vpc_peering.peering_connection_id
}
