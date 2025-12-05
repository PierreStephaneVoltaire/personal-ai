resource "kubernetes_service_account" "argocd_ai_platform" {
  metadata {
    name      = "argocd-application-controller"
    namespace = data.terraform_remote_state.kubernetes_base.outputs.namespace
  }
}

resource "kubernetes_role" "argocd_ai_platform" {
  metadata {
    name      = "argocd-application-controller"
    namespace = data.terraform_remote_state.kubernetes_base.outputs.namespace
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "argocd_ai_platform" {
  metadata {
    name      = "argocd-application-controller"
    namespace = data.terraform_remote_state.kubernetes_base.outputs.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argocd_ai_platform.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = data.terraform_remote_state.kubernetes_base.outputs.argocd_namespace
  }
}

resource "kubernetes_manifest" "ai_platform_app" {
  count = var.deploy_ai_platform ? 1 : 0

  field_manager {
    force_conflicts = true
  }

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ai-platform"
      namespace = data.terraform_remote_state.kubernetes_base.outputs.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        path           = "./k8s/ai-platform/overlays/production"
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "ai-platform"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
}
