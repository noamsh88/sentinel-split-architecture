output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EKS nodes land here)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (NAT gateways and public LBs)"
  value       = aws_subnet.public[*].id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables (used by the peering module to add cross-VPC routes)"
  value       = aws_route_table.private[*].id
}
