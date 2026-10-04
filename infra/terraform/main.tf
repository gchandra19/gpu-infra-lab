# Zonal GKE Standard cluster. One zonal cluster per billing account is covered
# by the GKE free tier, so the control plane is effectively free.
resource "google_container_cluster" "lab" {
  name     = var.cluster_name
  location = var.zone

  # Manage node pools separately; drop the default pool.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  release_channel {
    channel = var.release_channel
  }

  # Scale idle nodes (i.e. the GPU node) down faster than the default profile.
  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

  # System logs only — workload logs to Cloud Logging add cost and noise.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Managed DCGM metrics: GKE runs dcgm-exporter on GPU nodes and ships
  # DCGM_FI_* metrics to Managed Service for Prometheus / Cloud Monitoring.
  # Requires GKE-managed driver install (see gpu-pools.tf).
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "DCGM"]
    managed_prometheus {
      enabled = true
    }
  }
}

# Small always-on pool for kube-system, GMP collectors, etc.
resource "google_container_node_pool" "system" {
  name       = "system"
  cluster    = google_container_cluster.lab.id
  location   = var.zone
  node_count = var.cpu_node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.cpu_machine_type
    disk_type    = "pd-standard"
    disk_size_gb = 30
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = {
      pool = "system"
    }
  }
}
