# GPU monitoring

The cluster uses **GKE managed DCGM metrics** (`monitoring_config.enable_components = ["DCGM"]`
in `infra/terraform/main.tf`) rather than a self-hosted kube-prometheus-stack:

- GKE runs dcgm-exporter on each GPU node and scrapes it with Managed Service for Prometheus.
- No Prometheus/Grafana pods occupy the (paid) nodes, and there's no Helm release to manage.
- Metrics land in Cloud Monitoring as `prometheus.googleapis.com/DCGM_FI_*` and appear in the
  prebuilt **GKE → NVIDIA GPU Monitoring** dashboard (Monitoring → Dashboards).

Useful metrics for screenshots:

| Metric | Meaning |
|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | GPU utilization (%) |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | Tensor-core activity (0–1) |
| `DCGM_FI_DEV_FB_USED` | Framebuffer memory used (MiB) |
| `DCGM_FI_DEV_POWER_USAGE` | Power draw (W) |
| `DCGM_FI_DEV_GPU_TEMP` | Temperature (°C) |

PromQL (Metrics Explorer → PromQL):

```promql
avg by (Hostname) (DCGM_FI_DEV_GPU_UTIL{cluster="gpu-lab"})
max by (Hostname) (DCGM_FI_DEV_FB_USED{cluster="gpu-lab"})
max by (Hostname) (DCGM_FI_DEV_POWER_USAGE{cluster="gpu-lab"})
```
