# OIDC provider for GitHub Actions token federation
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Both active GitHub CA thumbprints — GitHub rotated its CA in 2023;
  # listing both ensures continuity if AWS still validates thumbprints.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

resource "aws_iam_role" "github_actions" {
  name        = "sentinel-github-actions-role"
  description = "Assumed by GitHub Actions via OIDC to run Terraform and deploy to EKS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "sentinel-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 / VPC / ELB — broad but necessary for Terraform-managed infra
      {
        Effect   = "Allow"
        Action   = ["ec2:*", "elasticloadbalancing:*", "autoscaling:*"]
        Resource = "*"
      },
      # EKS
      {
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      # IAM — scoped to the two approved prefixes only
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:role/eks-*",
          "arn:aws:iam::${var.account_id}:role/sentinel-*",
        ]
      },
      # OIDC providers (cluster OIDC + GitHub OIDC)
      {
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
        ]
        Resource = "arn:aws:iam::${var.account_id}:oidc-provider/*"
      },
      # Read-only IAM lookups (needed by Terraform plan)
      {
        Effect   = "Allow"
        Action   = ["iam:ListRoles", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicies"]
        Resource = "*"
      },
      # Terraform state backend
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::sentinel-terraform-state",
          "arn:aws:s3:::sentinel-terraform-state/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:*:${var.account_id}:table/sentinel-terraform-locks"
      },
    ]
  })
}
