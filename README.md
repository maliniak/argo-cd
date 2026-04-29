# EKS Fargate And Argo CD Bootstrap

This repository owns the shared platform layer:

- VPC, subnets, NAT, and EKS control plane
- Fargate profiles for platform and application namespaces
- AWS Load Balancer Controller
- Argo CD installation and bootstrap manifests
- ECR repositories for the sample lab applications

Application source code and Helm chart now live in the separate `lab` repository:

- `https://github.com/maliniak/lab.git`

## Repository Layout

```text
argo-cd/
  argocd/
    project.yaml
    root-application.yaml
    apps/
      demo-lab-dev.yaml
      demo-lab-prod.yaml
  terraform/
```

## What Gets Created

Terraform in [terraform](terraform) creates:

- a VPC with public and private subnets
- an EKS cluster on Fargate
- Fargate coverage for `kube-system`, `argocd`, `demo-dev`, and `demo-prod`
- ECR repositories under the `gitops-lab` prefix
- AWS Load Balancer Controller
- Argo CD with ALB ingress

Argo CD bootstrap manifests in [argocd](argocd) create:

- one root application: [argocd/root-application.yaml](argocd/root-application.yaml)
- two child applications:
  - [argocd/apps/demo-lab-dev.yaml](argocd/apps/demo-lab-dev.yaml)
  - [argocd/apps/demo-lab-prod.yaml](argocd/apps/demo-lab-prod.yaml)

Both child applications deploy the Helm chart from the separate `lab` repository.

## Prerequisites

- Terraform `>= 1.6`
- AWS credentials for the target account
- AWS CLI for kubeconfig and verification
- `kubectl`

## Quick Start

1. Initialize Terraform:

```bash
cd terraform
terraform init
```

2. Create and review variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Apply infrastructure:

```bash
terraform apply
```

4. Configure local kubeconfig:

```bash
aws eks update-kubeconfig --region eu-central-1 --name dev-eks-fargate
```

5. Apply Argo CD bootstrap manifests:

```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/root-application.yaml
```

## Multi-Environment Model

This setup runs both environments in one cluster:

- `demo-dev`: automatic development deployments
- `demo-prod`: explicit promotion deployments

The AppProject allows these destinations in [argocd/project.yaml](argocd/project.yaml).

## GitOps Wiring

- Root Argo application reads this repository from `argocd/apps`
- Child Argo applications read the app chart from `https://github.com/maliniak/lab.git`
- Dev uses `values-dev.yaml`
- Prod uses `values-prod.yaml`

## Operational Notes

- If the `lab` repository is private, Argo CD needs repository credentials.
- If you use Route53 hostnames, create DNS records for both environments and Argo CD.
- If you use HTTPS, attach an ACM certificate for the ALB ingress.

## Destroy

### Preserve ECR and state backend

ECR repositories and the Terraform state backend (S3 + DynamoDB) should survive a teardown so images and state are not lost.

Remove them from Terraform state before destroying:

```bash
cd terraform

terraform state rm \
  'aws_ecr_repository.gitops_lab["backend-orders"]' \
  'aws_ecr_repository.gitops_lab["backend-products"]' \
  'aws_ecr_repository.gitops_lab["frontend"]' \
  'aws_ecr_lifecycle_policy.gitops_lab["backend-orders"]' \
  'aws_ecr_lifecycle_policy.gitops_lab["backend-products"]' \
  'aws_ecr_lifecycle_policy.gitops_lab["frontend"]' \
  'aws_s3_bucket.tfstate' \
  'aws_s3_bucket_public_access_block.tfstate' \
  'aws_s3_bucket_server_side_encryption_configuration.tfstate' \
  'aws_s3_bucket_versioning.tfstate' \
  'aws_dynamodb_table.tfstate_lock'
```

### Clean up ALBs first

The AWS Load Balancer Controller creates ALBs from Kubernetes Ingress objects. These must be deleted before the cluster is destroyed, otherwise the VPC deletion will fail due to lingering ENIs.

1. Delete all Argo CD applications so the controller cannot re-create ingresses:

```bash
kubectl -n argocd delete application demo-lab-dev demo-lab-prod demo-root --wait=false
```

2. Delete the ingress objects in each namespace:

```bash
kubectl -n demo-dev delete ingress frontend
kubectl -n demo-prod delete ingress frontend 2>/dev/null || true
```

3. Wait ~30 seconds and verify the ALB is gone:

```bash
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-demo`)].{Name:LoadBalancerName,State:State.Code}' \
  --output table
```

The command should return an empty table before proceeding.

### Destroy the cluster

```bash
terraform destroy
```

This removes the VPC, EKS cluster, Fargate profiles, ArgoCD, Load Balancer Controller, KMS key, and all supporting IAM resources.

### Re-import preserved resources after a fresh apply

When you recreate the cluster, the existing `imports.tf` already re-adopts S3 and DynamoDB. To also re-adopt ECR, add import blocks to `imports.tf` before running `terraform apply`:

```hcl
import {
  to = aws_ecr_repository.gitops_lab["backend-orders"]
  id = "gitops-lab/backend-orders"
}
import {
  to = aws_ecr_repository.gitops_lab["backend-products"]
  id = "gitops-lab/backend-products"
}
import {
  to = aws_ecr_repository.gitops_lab["frontend"]
  id = "gitops-lab/frontend"
}
```
