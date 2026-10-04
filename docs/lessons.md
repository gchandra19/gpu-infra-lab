# Lessons

## Lab 1 — GKE GPU platform

- New projects can have `GPUS_ALL_REGIONS = 0`, which blocks GPU VMs even when the regional `NVIDIA_L4_GPUS` quota shows 1. Check both quotas, and request the global one first because approval isn't instant.
- Don't rely on GKE to taint GPU pools. It adds `nvidia.com/gpu=present:NoSchedule` only when the cluster already has a non-GPU pool, and Terraform created `system` and `l4-spot` in parallel right after removing the default pool. The GPU pool came up untainted. During the zero-node gap, the pending kube-system pods made the autoscaler scale `l4-spot` 0→1 (the only autoscaling pool), and kube-dns then pinned the GPU node at 1. Fix: declare the taint in `node_config`, then drain the node once.
- `gcloud` installed as a snap does not include `gke-gcloud-auth-plugin`. Install `google-cloud-cli-gke-gcloud-auth-plugin` from Google's apt repo, or `kubectl` cannot authenticate.
- Spot GPUs get preempted for real: the first load-test node was reclaimed (`compute.instances.preempted`) about 2 min after it started. With `backoffLimit: 0` the Job simply failed, and the autoscaler removed the empty replacement node. Budget for reruns, or add retries.
- The L4 holds its 72 W cap under sustained BF16 GEMM and lowers its clock to stay there (1000 → 930 MHz as it heats from 58 to 77 °C). Throughput drops about 12% over 5 minutes, so short benchmarks read high.
- GKE managed DCGM metrics can be queried without the console: `POST monitoring.googleapis.com/v1/projects/<p>/location/global/prometheus/api/v1/query_range` with PromQL such as `max(DCGM_FI_DEV_POWER_USAGE)`.
