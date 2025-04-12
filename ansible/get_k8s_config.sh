#!/usr/bin/env bash

# Get master host ip address from the ansible inventory file
INVENTORY_FILE="inventory.ini"
MASTER_HOST="master-0"

MASTER_ADDRESS=$(grep "${MASTER_HOST} ansible_host=" "$INVENTORY_FILE" |
  awk -F'=' '{print $2}' | tr -d ' ')

if [ -z "$MASTER_ADDRESS" ]; then
  echo "Error: No IP address found for host ${MASTER_HOST}."
  exit 1
fi

# Copy kube config from master node into ~/.kube/config
scp -o StrictHostKeyChecking=no \
  -i secrets/id_ed25519 \
  root@${MASTER_ADDRESS}:/etc/kubernetes/admin.conf ${HOME}/.kube/config

echo "Done!"
