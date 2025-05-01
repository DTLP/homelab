#!/usr/bin/env bash
# Original script from https://github.com/arturscheiner/kuberverse

WORKER_IP=$1
MASTER_TYPE=$2

cat /vagrant/hosts.out >> /etc/hosts

if [ $MASTER_TYPE = "single" ]; then
    $(cat /vagrant/kubeadm-init.out | grep -A 2 "kubeadm join" | sed -e 's/^[ \t]*//' | tr '\n' ' ' | sed -e 's/ \\ / /g')
else
    $(cat /vagrant/workers-join.out | sed -e 's/^[ \t]*//' | tr '\n' ' ' | sed -e 's/ \\ / /g')
fi

echo KUBELET_EXTRA_ARGS=--node-ip=${WORKER_IP} >> /etc/default/kubelet

systemctl restart kubelet