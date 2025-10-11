INVENTORY = inventory.ini

.PHONY: start
start: cluster ssh nvme ubuntu

.PHONY: stop
stop: shutdown

.PHONY: cluster
cluster:
	@echo "Running cluster setup playbook..."
	ansible-playbook -i $(INVENTORY) cluster_setup.yaml $(ARGS)

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
