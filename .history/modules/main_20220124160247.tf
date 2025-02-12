resource "argocd_project" "this" {
  metadata {
    name      = "argocd"
    namespace = var.argocd.namespace
    annotations = {
      "devops-stack.io/argocd_namespace" = var.argocd.namespace
    }
  }
 
  spec {
    description  = "argocd application project"
    source_repos = ["https://github.com/ducksify/devops-stack-module-argocd.git"]
 
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.namespace
    }
 
    orphaned_resources {
      warn = true
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

resource "htpasswd_password" "argocd_server_admin" {
  password = var.argocd.server_admin_password
}

data "utils_deep_merge_yaml" "values" {
  input = [ for i in var.profiles : templatefile("${path.module}/profiles/${i}.yaml", {
      base_domain           = var.base_domain,
      cluster_issuer        = var.cluster_issuer
      oidc                  = var.oidc

      argocd                = local.argocd
      repositories          = var.repositories
      server_admin_password = htpasswd_password.argocd_server_admin.bcrypt
  }) ]
}

resource "argocd_application" "this" {
  metadata {
    name      = "argocd"
    namespace = var.argocd.namespace
  }

  cascade = false

  spec {
    project = argocd_project.this.metadata.0.name

    source {
      repo_url        = "https://github.com/ducksify/devops-stack-module-argocd.git"
      path            = "charts/argocd"
      target_revision = "main"
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = var.namespace
    }

    sync_policy {
      automated = {
        prune     = true
        self_heal = true
      }

      sync_options = [
        "CreateNamespace=true"
      ]
    }
  }
}
