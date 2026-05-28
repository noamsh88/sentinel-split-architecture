# Sentinel Split Architecture — PoC

Two isolated EKS clusters communicating privately over a VPC peering connection, deployed entirely via GitHub Actions using Terraform modules.

---

## Architecture Overview

```
Internet
   │
   ▼
[Public NLB]  ── vpc-gateway (10.0.0.0/16) ──────────────────────────┐
                    │                                                   │
                    ▼                                                   │ VPC Peering
              [gateway-proxy]                                           │ (pcx-gateway-to-backend)
                 (nginx)                                                │
                    │ HTTP → 10.1.x.x                                   │
                    └────────────────────────────────────────────────────┘
                                                                        │
                                                          vpc-backend (10.1.0.0/16)
                                                               │
                                                               ▼
                                                         [Internal NLB]
                                                               │
                                                               ▼
                                                           [backend]
                                                        (http-echo pod)
                                                     "Hello from backend"
```

### Components

| Layer | Resource | CIDR / Details |
|---|---|---|
| vpc-gateway | VPC + 2 private + 2 public subnets | `10.0.0.0/16` |
| vpc-backend | VPC + 2 private + 2 public subnets | `10.1.0.0/16` |
| eks-gateway | Managed node group in private subnets | Public NLB exposes port 80 |
| eks-backend | Managed node group in private subnets | Internal NLB (no internet exposure) |
| VPC Peering | `pcx-gateway-to-backend` | Routes injected into all private route tables |

---

## Terraform Module Structure

```
terraform/
├── backend.tf          # S3 remote state + DynamoDB lock
├── providers.tf        # AWS + TLS providers
├── variables.tf        # Root inputs
├── main.tf             # Composes all modules
├── outputs.tf
└── modules/
    ├── vpc/            # VPC, subnets, IGW, NAT GW, route tables
    ├── eks/            # IAM roles, SGs, cluster, launch template, node group, OIDC
    ├── vpc-peering/    # Peering connection + routes in both VPCs
    └── iam/            # GitHub Actions OIDC provider + sentinel- role
```

Each module exposes clean `variables.tf` / `outputs.tf` with no hardcoded resource names.

---

## Prerequisites

### 1. Bootstrap Terraform state backend (one-time, run locally)

```bash
aws s3 mb s3://sentinel-terraform-state --region us-west-2
aws s3api put-bucket-versioning \
  --bucket sentinel-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket sentinel-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws dynamodb create-table \
  --table-name sentinel-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

### 2. Bootstrap the GitHub Actions IAM role (one-time, run locally)

A minimal bootstrapping role with permissions to create `sentinel-*` and `eks-*` IAM roles must already exist in the account. Run Terraform locally once with that role to create the `sentinel-github-actions-role`, then hand off to CI/CD:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set github_repo to your fork
terraform init
terraform apply -target=module.iam
```

### 3. GitHub repository secrets

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of `sentinel-github-actions-role` |

### 4. GitHub Actions environment

Create a **`production`** environment in GitHub → Settings → Environments. This gates the `apply` job behind an optional manual approval.

---

## Running the Pipeline

```
git push origin main
```

This triggers two sequential workflows:

1. **Infrastructure** (`infra.yml`) — validates → plans → applies Terraform  
2. **Deploy** (`deploy.yml`) — validates manifests → deploys backend → gets NLB DNS → deploys gateway → smoke tests

The smoke test curls the public NLB and asserts the response contains `Hello from backend`.

---

## Networking Deep Dive

### VPC design

Both VPCs use private subnets exclusively for nodes and control-plane ENIs. Public subnets exist only to host NAT Gateways (one per VPC for cost; two per VPC for HA). No EC2 instances are ever placed in public subnets.

### VPC Peering

A single peering connection (`pcx-gateway-to-backend`) links the two VPCs. Terraform injects bidirectional routes into every private route table:

- `10.1.0.0/16 → pcx` added to gateway's private route tables  
- `10.0.0.0/16 → pcx` added to backend's private route tables  
- DNS resolution across the peering link is enabled (`allow_remote_vpc_dns_resolution = true`)

### Cross-cluster traffic path

```
gateway-proxy pod
  → proxy_pass http://<backend-internal-NLB>:80
  → NLB (private, in backend VPC 10.1.x.x)
  → backend pod:5678
```

The backend NLB hostname is discovered after the backend service is deployed and injected into the nginx ConfigMap at deploy time via `sed`. This avoids hardcoding a DNS name that doesn't exist yet.

### Security Groups

| Rule | SG | Direction | Port | Source/Dest |
|---|---|---|---|---|
| Node-to-node | `eks-backend-node-sg` | Ingress | all | self |
| Control plane → nodes | both node SGs | Ingress | 1025-65535 + 443 | cluster SG |
| Peered VPC HTTP | `eks-backend-node-sg` | Ingress | 80 | `10.0.0.0/16` |
| All outbound | both node SGs | Egress | all | `0.0.0.0/0` |

The security group rule allowing `10.0.0.0/16 → port 80` on backend nodes is the key cross-VPC gate.

### Kubernetes NetworkPolicy

```yaml
# kubernetes/backend/network-policy.yaml
ingress:
  - from:
      - ipBlock: { cidr: 10.0.0.0/16 }  # gateway VPC
      - ipBlock: { cidr: 10.1.0.0/16 }  # backend VPC (NLB node IPs)
    ports:
      - port: 5678
```

Both CIDRs are needed because NLB source IP preservation depends on whether the target type is `instance` (preserves gateway IP) or `ip` (shows NLB node IP from backend CIDR). The NetworkPolicy acts as a defence-in-depth layer below the Security Group rule.

---

## IAM Role Naming

Per the permission boundary in this account, only two prefixes are allowed:

| Prefix | Used for |
|---|---|
| `eks-` | Cluster role (`eks-<name>-cluster-role`) and node role (`eks-<name>-node-role`) |
| `sentinel-` | GitHub Actions OIDC role (`sentinel-github-actions-role`) |

No IAM roles outside these prefixes are created or referenced.

---

## CI/CD Pipeline Structure

```
push to main
├── infra.yml
│   ├── validate   (fmt check, terraform validate, tflint)
│   ├── plan       (terraform plan, uploads artifact, comments on PR)
│   └── apply      (downloads artifact, terraform apply) ← main only
│
└── deploy.yml  (triggered by infra workflow_run: completed)
    ├── validate-manifests  (kubectl apply --dry-run=client)
    ├── deploy-backend      (eks-backend context, apply, wait for NLB)
    └── deploy-gateway      (eks-gateway context, render configmap, apply, smoke test)
```

**OIDC federation** means no long-lived AWS credentials exist anywhere in GitHub. The `sentinel-github-actions-role` trust policy binds to `repo:<owner>/<repo>:*` so only your repository can assume it.

---

## Trade-offs (3-day limit)

| Decision | Production alternative |
|---|---|
| Single NAT GW per VPC | One NAT GW per AZ (~$32/mo each) for HA |
| EKS public endpoint enabled | Restrict to VPN CIDR or use private endpoint + SSM port-forward |
| In-tree AWS cloud provider for NLBs | AWS Load Balancer Controller (better annotation support, cross-AZ, target-type=ip) |
| Hardcoded backend DNS in ConfigMap | ExternalDNS + Route53 private hosted zone shared across VPCs |
| No TLS | Cert-manager + ACM on NLBs; mTLS between proxy and backend via service mesh |
| http-echo image for backend | Real application image pushed to private ECR |
| No pod disruption budgets | PDB with `minAvailable: 1` for production workloads |
| Single peering connection | AWS Transit Gateway if you need >2 VPCs or hub-and-spoke routing |

---

## What I Would Do Next

- **TLS / mTLS**: Cert-manager for the public NLB (ACM), Istio or Linkerd for mTLS between proxy and backend
- **Observability**: Prometheus + Grafana via kube-prometheus-stack, Loki for logs, OpenTelemetry traces
- **GitOps**: ArgoCD or Flux managing Kubernetes state declaratively, replacing the `kubectl apply` step
- **Ingress**: Replace the raw NLB service with an NGINX Ingress Controller or AWS ALB Ingress Controller for path-based routing and SSL termination
- **Secret management**: AWS Secrets Manager + External Secrets Operator; Vault for dynamic credentials
- **Cost optimisation**: Karpenter for right-sized spot nodes; remove NAT GW in favour of VPC endpoints for ECR/S3; schedule scale-down for non-prod
- **Multi-AZ NAT**: One NAT GW per AZ for production-grade HA
- **Private EKS endpoint**: Combined with VPN Gateway or Direct Connect so CI/CD never touches the public internet path to the API server
