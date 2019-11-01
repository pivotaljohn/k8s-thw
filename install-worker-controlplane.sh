#!/usr/bin/env bash

set -euxo pipefail

sudo apt-get update
sudo apt-get -y install socat conntrack ipset

sudo swapon --show
sudo swapoff -a

# TODO: disable swap after boot


K8S_VERSION=1.15.3
CRI_VERSION=1.15.0
RUNC_VERSION=1.0.0-rc8
CNI_VERSION=0.8.2
CONTAINERD_VERSION=1.2.9

CNI_NETD_PATH=/etc/cni/net.d
CNI_BIN_PATH=/opt/cni/bin
KUBE_PROXY_CFG_PATH=/var/lib/kube-proxy
KUBELET_CFG_PATH=/var/lib/kubelet
K8S_CFG_PATH=/var/lib/kubernetes
K8S_RUN_PATH=/var/run/kubernetes

POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
	http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

wget -q --show-progress --https-only --timestamping \
	https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRI_VERSION}/crictl-v${CRI_VERSION}-linux-amd64.tar.gz \
	https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64 \
	https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz \
	https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz \
	https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubectl \
	https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-proxy \
	https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubelet

sudo mkdir -p \
	${CNI_NETD_PATH} \
	${CNI_BIN_PATH} \
	${KUBELET_CFG_PATH} \
	${K8S_CFG_PATH} \
	${K8S_RUN_PATH} \
	${KUBE_PROXY_CFG_PATH}
mkdir -p containerd

tar -xvf crictl-v${CRI_VERSION}-linux-amd64.tar.gz
tar -xvf containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz -C containerd
sudo tar -xvf cni-plugins-linux-amd64-v${CNI_VERSION}.tgz -C ${CNI_BIN_PATH}
sudo mv runc.amd64 runc

chmod +x crictl kubectl kube-proxy kubelet runc
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin
sudo mv containerd/bin/* /bin/

echo "*** CNI Networking ***"

echo "Configuring \"Bridge\" network ..."
cat <<EOF | sudo tee ${CNI_NETD_PATH}/10-bridge.conf
{
  "cniVersion": "0.3.1",
  "name": "bridge",
  "bdige": "cnio0",
  "isGateway": true,
  "isMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [{"subset": "${POD_CIDR}"}]
    ],
    "routes": [{"dst": "0.0.0.0/0"}]
  }
}
EOF

echo "Configuring \"loopback\" network ..."
cat <<EOF | sudo tee ${CNI_NETD_PATH}/99-loopback.conf
{
  "cniVersion": "0.3.1",
  "name": "lo",
  "type": "loopback"
}
EOF

echo "*** containerd ***"

sudo mkdir -p /etc/containerd

cat <<EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.liunx"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

echo "*** Kubelet ***"

sudo cp ${HOSTNAME}-key.pem ${HOSTNAME}.pem ${KUBELET_CFG_PATH}
sudo cp ${HOSTNAME}.kubeconfig ${KUBELET_CFG_PATH}/kubeconfig
sudo cp ca.pem ${K8S_CFG_PATH}

cat <<EOF | sudo tee ${KUBELET_CFG_PATH}/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "${K8S_CFG_PATH}/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tksCertFile: "${KUBELET_CFG_PATH}/${HOSTNAME}.pem"
tlsPrivateKeyFile: "${KUBELET_CFG_PATH}/${HOSTNAME}-key.pem"
EOF


cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubeneretes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.services

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=${KUBELET_CFG_PATH}/kubelet-config.yaml
  --container-runtime==remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=${KUBELET_CFG_PATH}/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


echo "*** kube-proxy ***"

sudo cp kube-proxy.kubeconfig ${KUBE_PROXY_CFG_PATH}/kubeconfig

cat <<EOF | sudo tee ${KUBE_PROXY_CFG_PATH}/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "${KUBE_PROXY_CFG_PATH}/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=${KUBE_PROXY_CFG_PATH}/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy

