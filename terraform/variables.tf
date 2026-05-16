variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name used for naming and tags."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Environment name, for example: dev, stage, prod."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Base EKS cluster name (environment is prefixed automatically)."
  type        = string
  default     = "eks-fargate"
}

variable "kubernetes_version" {
  description = "EKS control plane Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "fargate_namespaces" {
  description = "Kubernetes namespaces that should run on Fargate."
  type        = list(string)
  default     = ["kube-system", "argocd", "app"]
}

variable "gitops_lab_namespaces" {
  description = "Namespaces reserved for the Argo CD GitOps lab workloads (for example: dev and prod)."
  type        = list(string)
  default     = ["demo-dev", "demo-stage", "demo-prod"]
}

variable "enable_gitops_lab_ecr_repositories" {
  description = "Whether to create ECR repositories for the GitOps lab services."
  type        = bool
  default     = true
}

variable "gitops_lab_ecr_repository_prefix" {
  description = "Prefix used for the GitOps lab ECR repositories."
  type        = string
  default     = "gitops-lab"
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to install AWS Load Balancer Controller via Helm."
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_namespace" {
  description = "Namespace where AWS Load Balancer Controller is installed."
  type        = string
  default     = "kube-system"
}

variable "enable_argocd" {
  description = "Whether to install Argo CD via Helm."
  type        = bool
  default     = true
}

variable "enable_argocd_ingress" {
  description = "Whether to expose Argo CD through an ALB ingress. Disable when using port-forward only."
  type        = bool
  default     = false
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  type        = string
  default     = "argocd"
}

variable "argocd_hostname" {
  description = "Hostname for Argo CD Ingress. Leave empty to skip hostname-based routing."
  type        = string
  default     = ""
}

variable "argocd_alb_scheme" {
  description = "ALB scheme for Argo CD ingress. Either 'internet-facing' or 'internal'."
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.argocd_alb_scheme)
    error_message = "argocd_alb_scheme must be 'internet-facing' or 'internal'."
  }
}

variable "argocd_alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the Argo CD ALB. Leave empty for HTTP-only."
  type        = string
  default     = ""
}

variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform state. Must be globally unique."
  type        = string
  default     = "platform-eks-fargate-tfstate-eu-central-1"
}

variable "tfstate_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
  default     = "platform-eks-fargate-tfstate-lock"
}

variable "tags" {
  description = "Extra tags merged into all managed resources."
  type        = map(string)
  default     = {}
}
