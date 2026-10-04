variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region (used for the provider default)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the zonal cluster. Must offer nvidia-l4 (us-central1-a/b/c do)."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gpu-lab"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "cpu_machine_type" {
  description = "Machine type for the always-on system node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "cpu_node_count" {
  description = "Fixed size of the system node pool"
  type        = number
  default     = 1
}

variable "gpu_machine_type" {
  description = "Machine type for the GPU pool (g2-standard-4 = 1x L4, 4 vCPU, 16 GB)"
  type        = string
  default     = "g2-standard-4"
}

variable "gpu_max_nodes" {
  description = "Autoscaler ceiling for the GPU pool. Keep <= your GPU quota."
  type        = number
  default     = 1
}

variable "gpu_disk_size_gb" {
  description = "Boot disk for GPU nodes (CUDA/PyTorch images are large)"
  type        = number
  default     = 60
}
