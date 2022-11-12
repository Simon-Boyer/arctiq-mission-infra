resource "google_container_cluster" "primary" {
  name     = "arctiq-mission-cluster"
  location = "northamerica-northeast1"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "arctiq-mission-node-pool"
  location   = "northamerica-northeast1"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-highmem-2"
  }
}

resource "google_service_account" "crossplane_service_account" {
  account_id   = "crossplane"
  display_name = "GKE Service Account"
}

resource "google_project_iam_member" "project" {
  project = "arctiq-mission-simonboyer"
  role    = "roles/cloudsql.admin"
  member  = format("serviceAccount:%s", google_service_account.crossplane_service_account.email)
}

resource "google_project_service" "project" {
  project = "arctiq-mission-simonboyer"
  service = "sqladmin.googleapis.com"
}