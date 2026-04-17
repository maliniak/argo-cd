data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.environment}-${var.cluster_name}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  gitops_lab_namespaces = distinct(concat(var.fargate_namespaces, [var.gitops_lab_namespace]))

  gitops_lab_ecr_repositories = {
    backend-a = "${var.gitops_lab_ecr_repository_prefix}/backend-a"
    backend-b = "${var.gitops_lab_ecr_repository_prefix}/backend-b"
    frontend  = "${var.gitops_lab_ecr_repository_prefix}/frontend"
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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
  })
}

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

resource "aws_ecr_repository" "gitops_lab" {
  for_each = var.enable_gitops_lab_ecr_repositories ? local.gitops_lab_ecr_repositories : {}

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "gitops_lab" {
  for_each = aws_ecr_repository.gitops_lab

  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

module "aws_load_balancer_controller_irsa_role" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name}-aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.aws_load_balancer_controller_namespace}:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = var.aws_load_balancer_controller_namespace
  create_namespace = false

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role[0].iam_role_arn
  }

  depends_on = [
    module.eks,
    module.aws_load_balancer_controller_irsa_role,
  ]
}

resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = var.argocd_namespace
  create_namespace = false

  values = [
    yamlencode({
      global = {
        domain = var.argocd_hostname != "" ? var.argocd_hostname : "argocd.example.com"
      }

      configs = {
        params = {
          # ArgoCD talks plain HTTP; TLS is terminated at the ALB
          "server.insecure" = true
        }
      }

      server = {
        ingress = {
          enabled          = true
          controller       = "aws"
          ingressClassName = "alb"
          hostname         = var.argocd_hostname != "" ? var.argocd_hostname : null

          annotations = merge(
            {
              "alb.ingress.kubernetes.io/scheme"           = var.argocd_alb_scheme
              "alb.ingress.kubernetes.io/target-type"      = "ip"
              "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
              "alb.ingress.kubernetes.io/listen-ports"     = var.argocd_alb_certificate_arn != "" ? "[{\"HTTP\":80},{\"HTTPS\":443}]" : "[{\"HTTP\":80}]"
            },
            var.argocd_alb_certificate_arn != "" ? {
              "alb.ingress.kubernetes.io/certificate-arns" = var.argocd_alb_certificate_arn
              "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
            } : {}
          )

          aws = {
            serviceType            = "ClusterIP"
            backendProtocolVersion = "GRPC"
          }
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller,
  ]
}
