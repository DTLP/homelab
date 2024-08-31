INVENTORY = inventory.ini

.PHONY: all
all: cluster ssh ubuntu

.PHONY: cluster
cluster:
	@echo "Running cluster setup playbook..."
	ansible-playbook -i $(INVENTORY) cluster_setup.yaml

.PHONY: ssh
ssh:
	@echo "Running SSH setup playbook..."
	ansible-playbook -i $(INVENTORY) ssh_setup.yaml

.PHONY: ubuntu
ubuntu:
	@echo "Running Ubuntu Image playbook..."
	ansible-playbook -i $(INVENTORY) ubuntu_image.yaml
