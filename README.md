# gpu-infra-lab

Hands-on GPU infrastructure labs on Google Cloud: GKE GPU platform, LLM inference, GPU scheduling, and distributed training. Each lab records its measured numbers and its cost.

| Lab | Topic | Headline result | Status |
|---|---|---|---|
| [01](labs/01-gke-gpu-platform) | GKE + Terraform, Spot L4 scale-from-zero, DCGM monitoring | 90s cold start to a running GPU container; 53.6 BF16 TFLOPS (power-limited) | done |
| 02 | vLLM inference on H100: BF16 vs FP8, concurrency sweep | | planned |
| 03 | Kueue: quotas, priorities, gang scheduling | | planned |
| 04 | Distributed training: DDP vs FSDP, async checkpointing, NCCL | | planned |

See [docs/cost-log.md](docs/cost-log.md) for spend per session.

## Quick start

```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
make up && make smoke-test && make load
make down
```
