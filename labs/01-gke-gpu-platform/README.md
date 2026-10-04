# Lab 1 — GKE GPU platform

**Goal:** a reproducible GKE cluster, built with Terraform, whose Spot L4 GPU pool scales from zero
on demand, with DCGM GPU metrics, and with the cost kept to a few dollars per session.

## Architecture

| Component | Choice | Why |
|---|---|---|
| Cluster | Zonal GKE Standard, `us-central1-a`, REGULAR channel | GKE free tier covers one zonal control plane |
| System pool | 1× `e2-standard-2`, pd-standard 30 GB | Runs kube-system and GMP collectors |
| GPU pool | `g2-standard-4` (1× L4 24 GB), **Spot**, autoscale **0→1** | Costs nothing while idle |
| Drivers | GKE-managed (`gpu_driver_version = "LATEST"`) | No driver DaemonSet to maintain |
| Monitoring | GKE managed DCGM → Managed Prometheus / Cloud Monitoring | Runs no Prometheus or Grafana on paid nodes |
| Autoscaler | `OPTIMIZE_UTILIZATION` profile | Removes the idle GPU node sooner |

Terraform: [`infra/terraform`](../../infra/terraform). Manifests: [`infra/k8s`](../../infra/k8s).

## Runbook

```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars   # set project_id
make up            # timed terraform apply + get-credentials
make smoke-test    # nvidia-smi pod; times scale-from-zero
make load          # 5-min BF16 matmul load → screenshot DCGM graphs
make load-logs
make down          # timed destroy + leftover check
```

## Results

Session 2026-10-04, GKE `1.35.8-gke.1225000`, Terraform 1.16.5, NVIDIA driver 580.173.02.

| Metric | Value |
|---|---|
| `terraform apply` (cluster + pools) | **8m32s**, of which the control plane took 7m08s ([terraform-timing.csv](results/terraform-timing.csv)) |
| Scale from zero: pod created → GPU node registered / Ready | **33s / 35s** |
| Scale from zero: pod created → pod scheduled | **85s** (GPU device plugin and driver readiness) |
| Scale from zero: pod created → container started | **90s** ([scale-from-zero.csv](results/scale-from-zero.csv), [nvidia-smi.txt](results/nvidia-smi.txt)) |
| Idle GPU node → removed by autoscaler | about 2 min after it went empty (`OPTIMIZE_UTILIZATION`) |
| BF16 matmul throughput on L4 (N=8192, 300s) | **53.6 TFLOPS mean**, 59.0 peak, falling to about 51 as it heats up ([gpu-load.log](results/gpu-load.log)) |
| Spot preemptions | **1** of 2 GPU node runs, about 2 min in, during the image pull |
| `terraform destroy` | **8m56s** (system pool drain 4m21s, then the control plane 4m32s); leftover check clean |
| Spot `g2-standard-4` hourly cost (billing) | _pending; billing data lags about 24h_ |
| Total session cost | _pending_ (see [cost log](../../docs/cost-log.md)) |

### DCGM metrics during the load test

Pulled from Managed Prometheus as PromQL (`max(DCGM_FI_DEV_*)`, 30s step). Raw values are in [dcgm-metrics.txt](results/dcgm-metrics.txt).

| Time (UTC) | GPU util | FB used | Power | SM clock | Temp |
|---|---|---|---|---|---|
| 20:29 | 100% | 8936 MiB | 71.3 W | 990 MHz | 58 °C |
| 20:31 | 100% | 8936 MiB | 72.0 W | 960 MHz | 73 °C |
| 20:33 | 100% | 8936 MiB | 71.7 W | 930 MHz | 77 °C |

The L4 sits at its 72 W power cap for the whole run. As it heats up it holds the cap by lowering its clock (about 1000 → 930 MHz, against a 2040 MHz boost), so throughput falls from 57 to 51 TFLOPS. Sustained BF16 GEMM on an L4 is limited by power, not compute: about 44% of the 121 TFLOPS dense peak.

## What I learned

- Set the GPU taint explicitly in Terraform. GKE skipped it because both pools were created in parallel, and kube-system pods then pinned the GPU node at 1 (details in [lessons](../../docs/lessons.md)).
- Spot really does get preempted: 1 of 2 GPU nodes was reclaimed within minutes. A Job with `backoffLimit: 0` fails outright, so real workloads need retries, checkpointing, or a non-Spot fallback.
- Most of the scale-from-zero time is after the node is Ready: the GPU device plugin and driver take about 50s more before a GPU pod can schedule.
- The L4 is power-limited under sustained GEMM, so benchmarks shorter than about a minute overstate its throughput.
