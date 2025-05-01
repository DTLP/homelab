#!/usr/bin/env bash
# Original script from https://github.com/arturscheiner/kuberverse

NODE=$1
POD_CIDR=$2
MASTER_IP=$3
MASTER_TYPE=$4

cat /vagrant/hosts.out >> /etc/hosts

if [ $MASTER_TYPE = "single" ]; then
  kubeadm init --pod-network-cidr="${POD_CIDR}" --apiserver-advertise-address="${MASTER_IP}" --apiserver-cert-extra-sans="master.lab.local" --apiserver-cert-extra-sans="scaler.lab.local" | tee /vagrant/kubeadm-init.out

  k=$(grep -n "kubeadm join ${MASTER_IP}" /vagrant/kubeadm-init.out | cut -f1 -d:)
  x=$(echo $k | awk '{print $1}')
  awk -v ln=$x 'NR>=ln && NR<=ln+1' /vagrant/kubeadm-init.out | tee /vagrant/workers-join.out
else
  if (( $NODE == 0 )) ; then
    kubeadm init --control-plane-endpoint="scaler.lab.local:6443" --upload-certs --pod-network-cidr="${POD_CIDR}" --apiserver-advertise-address="${MASTER_IP}" --apiserver-cert-extra-sans="master.lab.local" --apiserver-cert-extra-sans="scaler.lab.local" | tee /vagrant/kubeadm-init.out

    k=$(grep -n "kubeadm join scaler.lab.local" /vagrant/kubeadm-init.out | cut -f1 -d:)
    x=$(echo $k | awk '{print $1}')
    awk -v ln=$x 'NR>=ln && NR<=ln+2' /vagrant/kubeadm-init.out | tee /vagrant/masters-join-default.out      
    awk -v ln=$x 'NR>=ln && NR<=ln+1' /vagrant/kubeadm-init.out | tee /vagrant/workers-join.out
  else
    sed "s+kubeadm join scaler.lab.local:6443+kubeadm join scaler.lab.local:6443 --apiserver-advertise-address ${MASTER_IP}+g" /vagrant/masters-join-default.out > /vagrant/masters-join-${NODE}.out
    $(cat /vagrant/masters-join-${NODE}.out | sed -e 's/^[ \t]*//' | tr '\n' ' ' | sed -e 's/ \\ / /g')
  fi
fi

mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

mkdir -p /vagrant/.kube
cp -i /etc/kubernetes/admin.conf /vagrant/.kube/config

if (( $NODE == 0 )) ; then
  wget -q https://docs.projectcalico.org/manifests/calico.yaml -O /tmp/calico-default.yaml
  sed "s+192.168.0.0/16+${POD_CIDR}+g" /tmp/calico-default.yaml > /tmp/calico-defined.yaml
  kubectl apply -f /tmp/calico-defined.yaml
fi

echo KUBELET_EXTRA_ARGS=--node-ip=${MASTER_IP} >> /etc/default/kubelet

systemctl restart kubelet