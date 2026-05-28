output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_security_group_id" {
  description = "Security group ID attached to worker nodes"
  value       = aws_security_group.node.id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA trust policies"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
