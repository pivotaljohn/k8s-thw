#!/usr/bin/env bash

K8S_EXTERNAL_IP=$(gcloud compute addresses describe k8s-the-hard-way--ip --region $(gcloud config get-value compute/region) --format=json)
K8S_PUBLIC_IP=$(jq -r .address <<< ${K8S_EXTERNAL_IP})

WORKERS=$(gcloud compute instances list --filter="tags.items=(worker)" --format=json | jq -r .[].name)

echo "Generating kubeconfig for workers:"
for worker in ${WORKERS}; do
  echo "---"
  echo "Configuring ${worker}..."
  echo "---"

  kubectl config set-cluster k8s-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${K8S_PUBLIC_IP}:6443 \
    --kubeconfig=${worker}.kubeconfig

  kubectl config set-credentials system:node:${worker} \
    --client-certificate=${worker}.pem \
    --client-key=${worker}-key.pem \
    --embed-certs=true \
    --kubeconfig=${worker}.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-the-hard-way \
    --user=system:node:${worker} \
    --kubeconfig=${worker}.kubeconfig

  kubectl config use-context default --kubeconfig=${worker}.kubeconfig
  echo -e "\n"
done

