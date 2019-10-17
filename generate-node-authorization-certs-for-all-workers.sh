#!/usr/bin/env bash

WORKERS=$(gcloud compute instances list --filter="tags.items=(worker)" --format=json | jq -r .[].name)

for worker in ${WORKERS}; do
  echo "Generating Certificate Signing Request (CSR) for node ${worker}..."
  cat >${worker}-csr.json <<EOF
{
  "CN": "system:node:${worker}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Los Angeles",
      "O": "system:nodes",
      "OU": "k8s The Hard Way",
      "ST": "California"
    }
  ]
}
EOF
  WORKER_DATA=$(gcloud compute instances describe ${worker} --format=json)
  EXTERNAL_IP=$(jq -r .networkInterfaces[0].accessConfigs[0].natIP <<< "${WORKER_DATA}")
  INTERNAL_IP=$(jq -r .networkInterfaces[0].networkIP <<< "${WORKER_DATA}")

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${worker},${EXTERNAL_IP},${INTERNAL_IP} \
    -profile=k8s_profile \
    ${worker}-csr.json | cfssljson -bare ${worker}
done
