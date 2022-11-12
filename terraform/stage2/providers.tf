provider "google" {
  project     = "arctiq-mission-simonboyer"
  region      = "northamerica-northeast1"
  zone        = "northamerica-northeast1-a"
}

data "google_client_config" "provider" {}

data "google_container_cluster" "primary" {
  name     = "arctiq-mission-cluster"
  location = "northamerica-northeast1"
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.primary.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate,
    )
  }
}

provider "kubectl" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate,
  )
  load_config_file = false
}

provider "cloudflare" {}
