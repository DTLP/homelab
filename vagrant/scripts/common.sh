#!/usr/bin/env bash
# Original script from https://github.com/arturscheiner/kuberverse

KUBE_VERSION=$1

UBUNTU_CODENAME=$(lsb_release -cs)

export DEBIAN_FRONTEND=noninteractive

### Install packages to allow apt to use a repository over HTTPS
apt update
apt install -y apt-transport-https ca-certificates curl software-properties-common apt-cacher-ng gpg

### Add Kubernetes GPG key
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

#### Kubernetes Repo
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

### Refresh apt cache install packages
apt update

apt install -y nfs-kernel-server nfs-common containerd software-properties-common \
  traceroute htop httpie bash-completion ruby socat conntrack net-tools \
  kubelet=${KUBE_VERSION}.* kubeadm=${KUBE_VERSION}.* kubectl=${KUBE_VERSION}.* kubernetes-cni

apt-mark hold kubelet kubeadm kubectl

### crictl
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${KUBE_VERSION}.0/crictl-v${KUBE_VERSION}.0-linux-amd64.tar.gz
tar -xzvf crictl-v${KUBE_VERSION}.0-linux-amd64.tar.gz
mv crictl /usr/local/bin

sed -i "s+# PassThroughPattern: \.\*+PassThroughPattern: .*+g" /etc/apt-cacher-ng/acng.conf
systemctl restart apt-cacher-ng
systemctl start apt-cacher-ng
systemctl enable apt-cacher-ng

echo -e 'Dpkg::Progress-Fancy "1";\nAPT::Color "1";' >> /etc/apt/apt.conf.d/99progress

### containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
mkdir -p /etc/containerd

### containerd config
cat > /etc/containerd/config.toml <<EOF
disabled_plugins = []
imports = []
oom_score = 0
plugin_dir = ""
required_plugins = []
root = "/var/lib/containerd"
state = "/run/containerd"
version = 2

[plugins]

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
base_runtime_spec = ""
container_annotations = []
pod_annotations = []
privileged_without_host_devices = false
runtime_engine = ""
runtime_root = ""
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
BinaryName = ""
CriuImagePath = ""
CriuPath = ""
CriuWorkPath = ""
IoGid = 0
IoUid = 0
NoNewKeyring = false
NoPivotRoot = false
Root = ""
ShimCgroup = ""
SystemdCgroup = true
EOF

### crictl uses containerd as default
{
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
}

sed -i "s+containerRuntimeEndpoint: \"\"+containerRuntimeEndpoint: \"unix:///run/containerd/containerd.sock\"+g" /var/lib/kubelet/config.yaml

### start services
systemctl daemon-reload
systemctl enable containerd && systemctl restart containerd
systemctl enable --now kubelet && systemctl start kubelet

kubeadm config images pull