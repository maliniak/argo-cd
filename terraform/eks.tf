module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cloudwatch_log_group = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  fargate_profiles = {
    for ns in local.gitops_lab_namespaces : ns => {
      name = ns
      selectors = [
        {
          namespace = ns
        }
      ]
      subnet_ids = module.vpc.private_subnets
      tags       = local.common_tags
    }
  }

  tags = local.common_tags
}
