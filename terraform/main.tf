data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.environment}-${var.cluster_name}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  gitops_lab_namespaces = distinct(concat(var.fargate_namespaces, [var.gitops_lab_namespace]))

  gitops_lab_ecr_repositories = {
    backend-orders   = "${var.gitops_lab_ecr_repository_prefix}/backend-orders"
    backend-products = "${var.gitops_lab_ecr_repository_prefix}/backend-products"
    frontend         = "${var.gitops_lab_ecr_repository_prefix}/frontend"
  }

  # Carve private and public subnets from one VPC CIDR for rapid account onboarding.
  private_subnets = [for idx, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, idx)]
  public_subnets  = [for idx, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, idx + 48)]

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
