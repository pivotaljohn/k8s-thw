#!/usr/bin/env bash

set -euo pipefail

K8S_GCP_REGION=$(gcloud config get-value compute/region)
K8S_EXTERNAL_ADDRESS=$(gcloud compute addresses describe k8s-the-hard-way--ip --region=${K8S_GCP_REGION} --format=json)
K8S_PUBLIC_IP=$(jq -r .address <<< ${K8S_EXTERNAL_ADDRESS})
CONTROLLERS=$(gcloud compute instances list --filter="tags.items=(controller)" --format=json | jq -r .[].name)

echo "Configuring GCP Health Check against the cluster..."

gcloud compute http-health-checks describe kubernetes >/dev/null 2>&1 || \
gcloud compute http-health-checks create kubernetes \
  --description "Kubernetes Health Check" \
  --host "kubernetes.default.svc.cluster.local" \
  --request-path "/healthz"

gcloud compute firewall-rules describe k8s-thw--allow-health-check >/dev/null 2>&1 || \
gcloud compute firewall-rules create k8s-thw--allow-health-check \
  --network k8s-the-hard-way \
  --source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \
  --allow tcp

POOL=k8s-apiserver-pool

echo "Ensure exists: load balancer at ${K8S_PUBLIC_IP}:6443 to the pool of controllers..."
gcloud compute target-pools describe ${POOL} >/dev/null 2>&1 || \
gcloud compute target-pools create ${POOL} \
  --http-health-check kubernetes && \
gcloud compute target-pools add-instances ${POOL} \
  --instances k8s-thw--controller-0,k8s-thw--controller-1,k8s-thw--controller-2

gcloud compute forwarding-rules describe kubernetes-forwarding-rule --region ${K8S_GCP_REGION} >/dev/null 2>&1 || \
gcloud compute forwarding-rules create kubernetes-forwarding-rule \
  --address ${K8S_PUBLIC_IP} \
  --ports 6443 \
  --region ${K8S_GCP_REGION} \
  --target-pool ${POOL}

echo "Verifying load balancer works..."
curl --cacert ca.pem https://${K8S_PUBLIC_IP}:6443/version
