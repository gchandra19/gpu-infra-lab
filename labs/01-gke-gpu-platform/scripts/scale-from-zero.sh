#!/usr/bin/env bash
# Measures GPU scale-from-zero: submits the nvidia-smi pod while the L4 pool is
# at 0 nodes, waits for it to finish, and records the timeline:
#   pod created -> node created -> node Ready -> pod scheduled -> container started
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
RES=$ROOT/labs/01-gke-gpu-platform/results
POD=gpu-smoke-test
SEL=cloud.google.com/gke-accelerator=nvidia-l4
TIMEOUT_S=${TIMEOUT_S:-1200}

existing=$(kubectl get nodes -l $SEL --no-headers 2>/dev/null | wc -l)
if [[ $existing -ne 0 ]]; then
  echo "WARNING: $existing GPU node(s) already up; this would not be a scale-from-zero run." >&2
  [[ ${FORCE:-0} == 1 ]] || { echo "Wait for scale-down or set FORCE=1." >&2; exit 1; }
fi

kubectl delete pod $POD --ignore-not-found --wait=true >/dev/null
kubectl apply -f "$ROOT/infra/k8s/smoke-test/nvidia-smi.yaml"
start=$(date +%s)

while :; do
  phase=$(kubectl get pod $POD -o jsonpath='{.status.phase}')
  nodes=$(kubectl get nodes -l $SEL --no-headers 2>/dev/null | wc -l)
  printf '\r[%4ds] pod=%-10s gpu_nodes=%s' $(( $(date +%s) - start )) "$phase" "$nodes"
  [[ $phase == Succeeded || $phase == Failed ]] && break
  (( $(date +%s) - start > TIMEOUT_S )) && { echo; echo "Timed out" >&2; exit 1; }
  sleep 5
done
echo

kubectl logs $POD | tee "$RES/nvidia-smi.txt"
node=$(kubectl get pod $POD -o jsonpath='{.spec.nodeName}')

python3 - "$RES/scale-from-zero.csv" "$phase" \
  <(kubectl get pod $POD -o json) <(kubectl get node "$node" -o json) <<'PY'
import csv, json, os, sys
from datetime import datetime

out, phase, pod_f, node_f = sys.argv[1:]
pod, node = json.load(open(pod_f)), json.load(open(node_f))
ts = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
cond = lambda obj, t: next(c["lastTransitionTime"] for c in obj["status"]["conditions"] if c["type"] == t)

pod_created = ts(pod["metadata"]["creationTimestamp"])
node_created = ts(node["metadata"]["creationTimestamp"])
node_ready = ts(cond(node, "Ready"))
scheduled = ts(cond(pod, "PodScheduled"))
started = ts(pod["status"]["containerStatuses"][0]["state"]["terminated"]["startedAt"])
s = lambda t: round((t - pod_created).total_seconds())

row = {
    "run_utc": pod_created.isoformat(),
    "node": node["metadata"]["name"],
    "machine": node["metadata"]["labels"].get("node.kubernetes.io/instance-type"),
    "spot": node["metadata"]["labels"].get("cloud.google.com/gke-spot", "false"),
    "node_created_s": s(node_created),
    "node_ready_s": s(node_ready),
    "pod_scheduled_s": s(scheduled),
    "container_started_s": s(started),
    "phase": phase,
}
new = not os.path.exists(out)
with open(out, "a", newline="") as f:
    w = csv.DictWriter(f, fieldnames=row.keys())
    if new:
        w.writeheader()
    w.writerow(row)
for k, v in row.items():
    print(f"{k:>20}: {v}")
PY

kubectl delete pod $POD --wait=false
