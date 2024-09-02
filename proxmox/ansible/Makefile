INVENTORY = inventory.ini

.PHONY: start
start: cluster ssh nvme ubuntu

.PHONY: stop
stop: shutdown

.PHONY: cluster
cluster:
	@echo "Running cluster setup playbook..."
	ansible-playbook -i $(INVENTORY) cluster_setup.yaml

.PHONY: nvme
nvme:
	@echo "Running NVMe setup playbook..."
	ansible-playbook -i $(INVENTORY) nvme_setup.yaml

.PHONY: ssh
ssh:
	@echo "Running SSH setup playbook..."
	ansible-playbook -i $(INVENTORY) ssh_setup.yaml

.PHONY: shutdown
shutdown:
	@echo "Running Shutdown PVE nodes setup playbook..."
	ansible-playbook -i $(INVENTORY) shutdown_pve_nodes.yaml

.PHONY: ubuntu
ubuntu:
	@echo "Running Ubuntu Image playbook..."
	ansible-playbook -i $(INVENTORY) ubuntu_image.yaml
