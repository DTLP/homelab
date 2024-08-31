#!/usr/bin/env bash

MASTER_NODE="192.168.1.30"

scp -o StrictHostKeyChecking=no \
	-i secrets/id_ed25519 \
	root@${MASTER_NODE}:/etc/kubernetes/admin.conf ${HOME}/.kube/config

echo "Done!"
