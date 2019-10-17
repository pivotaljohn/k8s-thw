#!/usr/bin/env bash

CONTROLLERS=$(gcloud compute instances list --filter="tags.items=(controller)" --format=json | jq -r .[].name)
echo "Distributing encryption configuration to controllers:"
for controller in ${CONTROLLERS}; do
  echo "- ${controller}"
  gcloud compute scp install-etcd.sh install-k8s-controlplane.sh configure-rbac-for-kublet-auth.sh ${controller}:~/
done
