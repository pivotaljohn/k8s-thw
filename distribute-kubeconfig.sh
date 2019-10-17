#!/usr/bin/env bash

WORKERS=$(gcloud compute instances list --filter="tags.items=(worker)" --format=json | jq -r .[].name)

echo "Distributing kubeconfig to workers (worker, kube-proxy):"
for worker in ${WORKERS}; do
  echo "- ${worker}"
  gcloud compute scp ${worker}.kubeconfig kube-proxy.kubeconfig ${worker}:~/
done

CONTROLLERS=$(gcloud compute instances list --filter="tags.items=(controller)" --format=json | jq -r .[].name)
echo "Distributing kubeconfig to controllers (controller, scheduler, and admin user):"
for controller in ${CONTROLLERS}; do
  echo "- ${controller}"
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${controller}:~/
done
