output "cluster_name" {
  value = google_container_cluster.lab.name
}

output "zone" {
  value = google_container_cluster.lab.location
}

output "master_version" {
  value = google_container_cluster.lab.master_version
}

output "get_credentials" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.lab.name} --zone ${google_container_cluster.lab.location} --project ${var.project_id}"
}
