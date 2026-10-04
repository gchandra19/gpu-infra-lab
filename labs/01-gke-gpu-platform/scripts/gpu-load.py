"""Simple GPU load generator: BF16 matmul loop for a fixed duration.

Produces a sustained, recognisable load for the DCGM graphs (utilization,
memory, power) and reports achieved TFLOPS.
"""
import json
import os
import time

import torch

DURATION_S = int(os.environ.get("DURATION_S", "300"))
N = int(os.environ.get("MATRIX_N", "8192"))
# Extra allocation (GiB) so the memory graph shows a clear step.
HOLD_GIB = float(os.environ.get("HOLD_GIB", "8"))
REPORT_EVERY_S = 10

assert torch.cuda.is_available(), "No CUDA device visible"
dev = torch.device("cuda")
name = torch.cuda.get_device_name(dev)
print(f"device={name} torch={torch.__version__} cuda={torch.version.cuda}", flush=True)

hold = torch.empty(int(HOLD_GIB * 2**30), dtype=torch.uint8, device=dev)
a = torch.randn(N, N, device=dev, dtype=torch.bfloat16)
b = torch.randn(N, N, device=dev, dtype=torch.bfloat16)

for _ in range(3):  # warmup
    a @ b
torch.cuda.synchronize()

flops_per_mm = 2 * N**3
start = last = time.time()
iters = window_iters = 0
samples = []
while time.time() - start < DURATION_S:
    c = a @ b
    iters += 1
    window_iters += 1
    if window_iters % 10 == 0:
        torch.cuda.synchronize()
        now = time.time()
        if now - last >= REPORT_EVERY_S:
            tflops = window_iters * flops_per_mm / (now - last) / 1e12
            samples.append(tflops)
            print(f"t={now - start:6.0f}s  {tflops:6.1f} TFLOPS  "
                  f"mem_alloc={torch.cuda.memory_allocated() / 2**30:.1f} GiB", flush=True)
            last, window_iters = now, 0
torch.cuda.synchronize()

summary = {
    "device": name,
    "matrix_n": N,
    "dtype": "bf16",
    "duration_s": round(time.time() - start, 1),
    "iterations": iters,
    "tflops_mean": round(sum(samples) / len(samples), 1) if samples else None,
    "tflops_max": round(max(samples), 1) if samples else None,
    "max_mem_allocated_gib": round(torch.cuda.max_memory_allocated() / 2**30, 2),
}
print("SUMMARY " + json.dumps(summary), flush=True)
del hold
