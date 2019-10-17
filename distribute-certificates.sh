#!/usr/bin/env bash

WORKERS=$(gcloud compute instances list --filter="tags.items=(worker)" --format=json | jq -r .[].name)

echo "Distributing with CA cert, node cert, node private key to worker nodes:"
for worker in ${WORKERS}; do
  echo "- ${worker}"
  gcloud compute scp ca.pem ${worker}-key.pem ${worker}.pem ${worker}:~/
done
echo "done."


CONTROLLERS=$(gcloud compute instances list --filter="tags.items=(controller)" --format=json | jq -r .[].name)
echo "Distributing CA cert & private key, 'kubernetes' service cert & private key, 'service-account' cert & private key:"
for controller in ${CONTROLLERS}; do
  echo "- ${controller}"
  gcloud compute scp ca.pem ca-key.pem kubernetes.pem kubernetes-key.pem service-account.pem service-account-key.pem ${controller}:~/
done
