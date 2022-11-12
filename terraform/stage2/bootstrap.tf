data "cloudflare_zone" "zone" {
  name = var.zone
}

# Zone permissions
data "cloudflare_api_token_permission_groups" "all" {}

# Token allowed to edit DNS entries and TLS certs for specific zone.
resource "cloudflare_api_token" "dns_edit" {
  name = "dns_edit"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.permissions["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.permissions["Zone Read"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.zone.zone_id}" = "*"
    }
  }
}

resource "google_service_account_key" "crossplane_service_account_key" {
  service_account_id = "crossplane"
}


resource "kubernetes_namespace" "traefik" {
    depends_on = [
      data.google_container_cluster.primary
    ]
    metadata {
        name = "traefik"
    }
}

resource "kubernetes_namespace" "crossplane_system" {
    depends_on = [
        data.google_container_cluster.primary
    ]
    metadata {
            name = "crossplane-system"
        }
}

resource "kubernetes_namespace" "argocd" {
    depends_on = [
      data.google_container_cluster.primary
    ]
    metadata {
        name = "argocd"
    }
}

resource "kubernetes_secret" "cloudflare_api" {
  depends_on = [
    kubernetes_namespace.traefik
  ]
  metadata {
    name = "cloudflare-api"
    namespace = "traefik"
  }
  data = {
    apikey = cloudflare_api_token.dns_edit.value
  }
  type = "Opaque"
}


resource "kubernetes_secret" "gcp_crossplane" {
  depends_on = [
    kubernetes_namespace.crossplane_system
  ]
  metadata {
    name = "gcp-creds"
    namespace = "crossplane-system"
  }
  data = {
    creds = base64decode(google_service_account_key.crossplane_service_account_key.private_key)
  }  
  type = "Opaque"
}

resource "helm_release" "traefik" {
    name       = "traefik"
    repository = "https://helm.traefik.io/traefik"
    chart      = "traefik"
    version    = "19.0.4"
    namespace = "traefik"
    values = [
    "${file("traefik-values.yaml")}"
  ]
}

resource "helm_release" "argocd" {
    name       = "argocd"
    repository = "https://argoproj.github.io/argo-helm"
    chart      = "argo-cd"
    version    = "5.13.7"
    namespace = "argocd"

    set {
      name = "server.config.kustomize\\.buildOptions"
      value = "--load-restrictor LoadRestrictionsNone --enable-helm"
    }

    set {
      name = "configs.params.server\\.insecure"
      value = "true"
      type = "string"
    }

    set {
      name = "server.config.application\\.resourceTrackingMethod"
      value = "annotation"
    }
}

resource "kubectl_manifest" "argocd_self_app" {
  depends_on = [
    helm_release.argocd,
    helm_release.traefik
  ]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: default
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  source:
    repoURL: 'https://github.com/Simon-Boyer/arctiq-mission-infra'
    path: kube-tools/argocd
  syncPolicy:
    automated:
      selfHeal: true
YAML
}

data "kubernetes_service" "traefik" {
  metadata {
    name = "traefik"
    namespace = "traefik"
  }
  depends_on = [
    helm_release.traefik
  ]
}

resource "cloudflare_record" "a_record" {
  zone_id = data.cloudflare_zone.zone.zone_id
  name    = "*.${var.subdomain}"
  value   = data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  ttl     = 1
  depends_on = [
    helm_release.traefik
  ]
}

