#!/usr/bin/env bash

KUBECONFIG_FILE=kube-controller-manager.kubeconfig

kubectl config set-cluster k8s-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config set-context default \
  --cluster=k8s-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=${KUBECONFIG_FILE}

kubectl config use-context default --kubeconfig=${KUBECONFIG_FILE}
