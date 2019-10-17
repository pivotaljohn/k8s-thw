#!/usr/bin/env bash

K8S_EXTERNAL_IP=$(gcloud compute addresses describe k8s-the-hard-way--ip --region $(gcloud config get-value compute/region) --format=json)
K8S_PUBLIC_IP=$(jq -r .address <<< ${K8S_EXTERNAL_IP})

KUBECONFIG_FILE=kube-proxy.kubeconfig

kubectl config set-cluster k8s-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${K8S_PUBLIC_IP}:6443 \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config set-context default \
  --cluster=k8s-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config use-context default --kubeconfig=${KUBECONFIG_FILE}
