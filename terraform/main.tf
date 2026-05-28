data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPCs ──────────────────────────────────────────────────────────────────────

module "vpc_gateway" {
  source = "./modules/vpc"

  name                 = "gateway"
  vpc_cidr             = var.gateway_vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  cluster_name         = "eks-gateway"
  environment          = var.environment
}

module "vpc_backend" {
  source = "./modules/vpc"

  name                 = "backend"
  vpc_cidr             = var.backend_vpc_cidr
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
  cluster_name         = "eks-backend"
  environment          = var.environment
}

# ── VPC Peering ────────────────────────────────────────────────────────────────

module "vpc_peering" {
  source = "./modules/vpc-peering"

  requester_vpc_id                  = module.vpc_gateway.vpc_id
  accepter_vpc_id                   = module.vpc_backend.vpc_id
  requester_vpc_cidr                = var.gateway_vpc_cidr
  accepter_vpc_cidr                 = var.backend_vpc_cidr
  requester_private_route_table_ids = module.vpc_gateway.private_route_table_ids
  accepter_private_route_table_ids  = module.vpc_backend.private_route_table_ids
  environment                       = var.environment
}

# ── IAM (OIDC role for GitHub Actions) ────────────────────────────────────────

module "iam" {
  source = "./modules/iam"

  github_repo = var.github_repo
  account_id  = data.aws_caller_identity.current.account_id
  environment = var.environment
}

# ── EKS Clusters ──────────────────────────────────────────────────────────────

module "eks_gateway" {
  source = "./modules/eks"

  cluster_name        = "eks-gateway"
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc_gateway.vpc_id
  subnet_ids          = module.vpc_gateway.private_subnet_ids
  environment         = var.environment
  instance_type       = var.eks_node_instance_type
  desired_size        = var.eks_node_desired_size
  min_size            = var.eks_node_min_size
  max_size            = var.eks_node_max_size

  # Nodes must reach backend VPC for cross-cluster traffic
  extra_egress_cidr_blocks = [var.backend_vpc_cidr]
}

module "eks_backend" {
  source = "./modules/eks"

  cluster_name       = "eks-backend"
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc_backend.vpc_id
  subnet_ids         = module.vpc_backend.private_subnet_ids
  environment        = var.environment
  instance_type      = var.eks_node_instance_type
  desired_size       = var.eks_node_desired_size
  min_size           = var.eks_node_min_size
  max_size           = var.eks_node_max_size

  # Only allow inbound HTTP from the gateway VPC CIDR (enforced at SG level)
  extra_ingress_cidr_blocks = [var.gateway_vpc_cidr]
}

# ── EKS Access Entries (grants CI/CD role kubectl admin) ──────────────────────

resource "aws_eks_access_entry" "github_gateway" {
  cluster_name  = module.eks_gateway.cluster_name
  principal_arn = module.iam.github_actions_role_arn
  type          = "STANDARD"

  depends_on = [module.eks_gateway, module.iam]
}

resource "aws_eks_access_policy_association" "github_gateway_admin" {
  cluster_name  = module.eks_gateway.cluster_name
  principal_arn = module.iam.github_actions_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_gateway]
}

resource "aws_eks_access_entry" "github_backend" {
  cluster_name  = module.eks_backend.cluster_name
  principal_arn = module.iam.github_actions_role_arn
  type          = "STANDARD"

  depends_on = [module.eks_backend, module.iam]
}

resource "aws_eks_access_policy_association" "github_backend_admin" {
  cluster_name  = module.eks_backend.cluster_name
  principal_arn = module.iam.github_actions_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_backend]
}
