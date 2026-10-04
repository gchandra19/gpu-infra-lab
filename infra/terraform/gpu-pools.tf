# Spot L4 pool that autoscales from zero. While no pod requests
# nvidia.com/gpu, this pool has 0 nodes and costs nothing.
resource "google_container_node_pool" "l4_spot" {
  name               = "l4-spot"
  cluster            = google_container_cluster.lab.id
  location           = var.zone
  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = var.gpu_max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.gpu_machine_type
    spot         = true
    disk_type    = "pd-balanced" # G2 does not support pd-standard
    disk_size_gb = var.gpu_disk_size_gb
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    # Set the GPU taint explicitly. GKE adds it automatically only when the
    # cluster already has a non-GPU pool, and this pool is created in parallel
    # with "system", so without this kube-system pods can land here and pin the
    # node at 1. Pods requesting nvidia.com/gpu get the toleration injected.
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    labels = {
      pool = "l4-spot"
    }
  }
}
