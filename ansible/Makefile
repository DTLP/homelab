INVENTORY = inventory.ini
START_PLAYBOOKS = cluster_setup.yaml ssh_setup.yaml nvme_setup.yaml ubuntu_image.yaml nic_tuning.yaml

.PHONY: check
check:
	@echo "Checking playbook syntax..."
	ansible-playbook -i $(INVENTORY) --syntax-check $(START_PLAYBOOKS)

.PHONY: dry-run
dry-run: check
	@echo "Running the start playbooks in check mode..."
	ansible-playbook -i $(INVENTORY) --check --diff $(START_PLAYBOOKS) $(ARGS)

.PHONY: start
start: check cluster ssh nvme ubuntu nic

.PHONY: stop
stop: shutdown

.PHONY: cluster
cluster:
	@echo "Running cluster setup playbook..."
	ansible-playbook -i $(INVENTORY) cluster_setup.yaml $(ARGS)

.PHONY: nic
nic:
	@echo "Running NIC tuning playbook..."
	ansible-playbook -i $(INVENTORY) nic_tuning.yaml $(ARGS)

.PHONY: nvme
nvme:
	@echo "Running NVMe setup playbook..."
	ansible-playbook -i $(INVENTORY) nvme_setup.yaml $(ARGS)

.PHONY: ssh
ssh:
	@echo "Running SSH setup playbook..."
	ansible-playbook -i $(INVENTORY) ssh_setup.yaml $(ARGS)

.PHONY: reboot
reboot:
	@echo "Rebooting Proxmox nodes..."
	ansible-playbook -i $(INVENTORY) reboot_nodes.yaml $(ARGS)

.PHONY: shutdown
shutdown:
	@echo "Shuting down Proxmox nodes..."
	ansible-playbook -i $(INVENTORY) shutdown_nodes.yaml $(ARGS)

.PHONY: ubuntu
ubuntu:
	@echo "Running Ubuntu Image playbook..."
	ansible-playbook -i $(INVENTORY) ubuntu_image.yaml $(ARGS)

.PHONY: upgrade
upgrade:
	@echo "Running System Upgrade playbook..."
	ansible-playbook -i $(INVENTORY) dist_upgrade.yaml $(ARGS)
