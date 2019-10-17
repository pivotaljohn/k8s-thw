#!/usr/bin/env bash

K8S_EXTERNAL_ADDRESS=$(gcloud compute addresses describe k8s-the-hard-way--ip --region=$(gcloud config get-value compute/region) --format=json)
K8S_PUBLIC_IP=$(jq -r .address <<< ${K8S_EXTERNAL_ADDRESS})

INTERNAL_CLUSTER_SVCS_IP=10.32.0.1
CONTROLLER_IPS=10.240.0.10,10.240.0.11,10.240.0.12
K8S_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Los Angeles",
      "O": "Kubernetes",
      "OU": "k8s The Hard Way",
      "ST": "California"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=k8s_profile \
  -hostname=${INTERNAL_CLUSTER_SVCS_IP},${CONTROLLER_IPS},${K8S_PUBLIC_IP},127.0.0.1,${K8S_HOSTNAMES} \
  kubernetes-csr.json | cfssljson -bare kubernetes
