#!/usr/bin/env bash
# After `make down`: confirm nothing billable from this lab is still around.
P=${PROJECT:-$(gcloud config get-value project 2>/dev/null)}
echo "== GKE clusters";     gcloud container clusters list --project "$P" --format="table(name,location,status)"
echo "== GPU / GKE VMs";    gcloud compute instances list --project "$P" --filter="name~^gke- OR guestAccelerators:*" --format="table(name,zone,status)"
echo "== Unattached disks"; gcloud compute disks list --project "$P" --filter="-users:*" --format="table(name,zone,sizeGb)"
echo "== Load balancers";   gcloud compute forwarding-rules list --project "$P" --format="table(name,region)"
