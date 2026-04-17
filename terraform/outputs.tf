output "cluster_name" {
  description = "Created EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Running EKS control plane version."
  value       = module.eks.cluster_version
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID used by the cluster."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by Fargate profiles."
  value       = module.vpc.private_subnets
}

output "gitops_lab_namespace" {
  description = "Namespace targeted by the sample Argo CD GitOps lab."
  value       = var.gitops_lab_namespace
}

output "gitops_lab_ecr_repository_urls" {
  description = "ECR repository URLs for the GitOps lab services."
  value = {
    for name, repo in aws_ecr_repository.gitops_lab : name => repo.repository_url
  }
}
