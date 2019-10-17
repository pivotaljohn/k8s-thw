#!/usr/bin/env bash

CONTROLLERS=$(gcloud compute instances list --filter="tags.items=(controller)" --format=json | jq -r .[].name)
echo "Distributing encryption configuration to controllers:"
for controller in ${CONTROLLERS}; do
  echo "- ${controller}"
  gcloud compute scp encryption-config.yaml ${controller}:~/
done
