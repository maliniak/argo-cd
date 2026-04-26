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
aws eks update-kubeconfig --region eu-central-1 --name <environment>-<cluster_name>
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

Delete ingress resources first so ALBs and ENIs are cleaned up before cluster deletion.

Then run:

```bash
cd terraform
terraform destroy
```

If Terraform blocks on the state bucket or lock table, that is expected when `prevent_destroy` is enabled.
