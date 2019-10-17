#!/usr/bin/env bash

#TODO: check that this is being run on a controller

ETCD_VERSION=v3.4.0
ETCD_BASENAME=etcd-${ETCD_VERSION}-linux-amd64
ETCD_TARBALL=${ETCD_BASENAME}.tar.gz
ETCD_INSTALL_DIR=/etc/etcd
ETCD_LIB_DIR=/var/lib/etcd
ETCD_NAME=$(hostname -s)
CLIENT_REQ_PORT=2379
PEER_COMMO_PORT=2380

# see also: https://cloud.google.com/compute/docs/storing-retrieving-metadata
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

echo "Downloading etcd..."
wget -q --show-progress --https-only --timestamping \
"https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/${ETCD_TARBALL}"

echo "Installing etcd binaries to /usr/local/bin/..."
tar -xvf ${ETCD_TARBALL}
sudo mv ${ETCD_BASENAME}/etcd* /usr/local/bin/

echo "Configuring etcd..."
sudo mkdir -p ${ETCD_INSTALL_DIR} ${ETCD_LIB_DIR}
sudo cp ca.pem kubernetes.pem kubernetes-key.pem ${ETCD_INSTALL_DIR}

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:${PEER_COMMO_PORT} \\
  --listen-peer-urls https://${INTERNAL_IP}:${PEER_COMMO_PORT} \\
  --listen-client-urls https://${INTERNAL_IP}:${CLIENT_REQ_PORT},https://127.0.0.1:${CLIENT_REQ_PORT} \\
  --advertise-client-urls https://${INTERNAL_IP}:${CLIENT_REQ_PORT} \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster k8s-thw--controller-0=https://10.240.0.10:${PEER_COMMO_PORT},k8s-thw--controller-1=https://10.240.0.11:${PEER_COMMO_PORT},k8s-thw--controller-2=https://10.240.0.12:${PEER_COMMO_PORT} \\
  --initial-cluster-state new \\
  --data-dir ${ETCD_LIB_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
