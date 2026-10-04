TF_DIR  := infra/terraform
LAB1    := labs/01-gke-gpu-platform
PROJECT ?= $(shell gcloud config get-value project 2>/dev/null)

.PHONY: init plan up creds smoke-test load load-logs down check

init:
	terraform -chdir=$(TF_DIR) init

plan: init
	terraform -chdir=$(TF_DIR) plan

## Create the cluster (timed) and fetch kubeconfig
up:
	$(LAB1)/scripts/timed-apply.sh apply
	$(MAKE) creds

creds:
	$$(terraform -chdir=$(TF_DIR) output -raw get_credentials)

## Scale-from-zero test: nvidia-smi pod on a fresh Spot L4 node (timed)
smoke-test:
	$(LAB1)/scripts/scale-from-zero.sh

## Matmul load for DCGM graphs (5 min)
load:
	kubectl create configmap gpu-load --from-file=$(LAB1)/scripts/gpu-load.py --dry-run=client -o yaml | kubectl apply -f -
	kubectl delete job gpu-load --ignore-not-found
	kubectl apply -f $(LAB1)/scripts/gpu-load-job.yaml
	@echo "Follow with: make load-logs"

load-logs:
	kubectl logs -f job/gpu-load

## Destroy everything (timed) and check for leftovers
down:
	-kubectl delete job gpu-load --ignore-not-found
	-kubectl delete pod gpu-smoke-test --ignore-not-found
	$(LAB1)/scripts/timed-apply.sh destroy
	$(MAKE) check

check:
	PROJECT=$(PROJECT) $(LAB1)/scripts/check-leftovers.sh
