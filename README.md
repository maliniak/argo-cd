# EKS Fargate Terraform Bootstrap

This repository bootstraps a new AWS account with:

- Dedicated VPC (public + private subnets across multiple AZs)
- EKS cluster using the `terraform-aws-modules/eks/aws` module
- Fargate profiles for selected namespaces
- IRSA enabled for IAM Roles for Service Accounts
- Managed EKS add-ons (`coredns`, `kube-proxy`, `vpc-cni`)
- AWS Load Balancer Controller installed via Helm (ALB/NLB ingress support)
- Argo CD installed via Helm in the `argocd` namespace

## Add-ons To Use

For this Fargate-first EKS setup, use the following:

- `vpc-cni` (required): Pod networking
- `kube-proxy` (required): Cluster service networking
- `coredns` (required): DNS for workloads; configured to run on Fargate
- `aws-load-balancer-controller` (recommended): Creates and manages ALB/NLB from Kubernetes Ingress/Service
- `argocd` (recommended): GitOps controller for cluster and application delivery

Optional add-ons you can add later:

- `metrics-server`: Metrics for HPA and observability
- `external-dns`: Route53 DNS record automation
- `cert-manager`: TLS certificate management

## Prerequisites

- Terraform >= 1.6
- AWS credentials for the target account
- Optional: AWS CLI for kubeconfig setup

## Quick Start

1. Initialize:

   ```bash
   cd terraform
   terraform init
   ```

2. Create your vars file:

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Review and adjust values in `terraform.tfvars`.

4. Plan and apply:

   ```bash
   cd terraform
   terraform plan
   terraform apply
   ```

5. Configure kubectl (after apply):

   ```bash
   aws eks update-kubeconfig --region <region> --name <environment>-<cluster_name>
   ```

## Notes For New Account Onboarding

- Keep `single_nat_gateway = true` initially to reduce cost in sandbox/new accounts.
- Tag strategy is centralized in `var.tags` and `locals.common_tags`.
- `kubernetes_version` is pinned in variables for predictable rollouts. Set it to the latest supported EKS version in your region before apply.
- Fargate runs only workloads matching `fargate_namespaces`; add namespaces as needed.
- The sample GitOps lab uses the `demo` namespace and ECR repositories under the `gitops-lab` prefix.

## Argo CD Lab

The repository now includes a starter GitOps lab under `lab/`:

- `lab/apps/`: three small Python services
- `lab/k8s/base/`: kustomize manifests for the demo namespace
- `lab/argocd/`: AppProject and Application definitions
- `.github/workflows/lab-build-and-release.yaml`: build, push, and manifest-bump workflow for ECR

See `lab/README.md` for the end-to-end setup and the AWS GitHub Actions integration steps.

## Cleanup

```bash
cd terraform
terraform destroy
```
