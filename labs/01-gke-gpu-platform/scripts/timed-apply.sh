#!/usr/bin/env bash
# Times `terraform apply` or `terraform destroy` end to end and appends the
# result to results/terraform-timing.csv.
#   usage: timed-apply.sh apply|destroy
set -euo pipefail
ACTION=${1:-apply}
ROOT=$(git rev-parse --show-toplevel)
TF_DIR=$ROOT/infra/terraform
OUT=$ROOT/labs/01-gke-gpu-platform/results/terraform-timing.csv

[[ -f $OUT ]] || echo "timestamp_utc,action,seconds,terraform_version,gke_version,exit_code" > "$OUT"

terraform -chdir="$TF_DIR" init -input=false >/dev/null
start=$(date +%s)
set +e
terraform -chdir="$TF_DIR" "$ACTION" -auto-approve -input=false
rc=$?
set -e
secs=$(( $(date +%s) - start ))

gke=$(terraform -chdir="$TF_DIR" output -raw master_version 2>/dev/null || echo "")
tfv=$(terraform version -json | python3 -c 'import json,sys;print(json.load(sys.stdin)["terraform_version"])')
echo "$(date -u +%FT%TZ),$ACTION,$secs,$tfv,$gke,$rc" >> "$OUT"
printf '\n%s took %dm%02ds (exit %d) -> %s\n' "$ACTION" $((secs/60)) $((secs%60)) "$rc" "$OUT"
exit $rc
