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
  timeout          = 500  # 15 minutes for ArgoCD to become ready
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      global = var.argocd_hostname != "" ? {
        domain = var.argocd_hostname
      } : {}

      configs = {
        params = {
          # ArgoCD talks plain HTTP; TLS is terminated at the ALB
          "server.insecure" = true
        }

        cm = {
          url = var.argocd_hostname != "" ? "https://${var.argocd_hostname}" : "http://localhost:8080"
        }
      }

      server = {
        ingress = merge(
          {
            enabled          = var.enable_argocd_ingress
            controller       = "aws"
            ingressClassName = "alb"

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
              backendProtocolVersion = "HTTP1"
            }
          },
          var.argocd_hostname != "" ? { hostname = var.argocd_hostname } : {}
        )
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller,
  ]
}
