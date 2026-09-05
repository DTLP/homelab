SHELL=/usr/bin/env bash

# Forward Proxmox provisioning targets to the ansible Makefile.
.PHONY: start stop cluster nvme ssh reboot shutdown ubuntu upgrade
start upgrade stop cluster nvme ssh reboot shutdown ubuntu:
	$(MAKE) -C ansible $@

hooks-install:
	-rm .git/hooks/pre-commit
	(cd .git/hooks/ && ln -s ../../scripts/pre-commit pre-commit)

bootstrap:
	./scripts/bootstrap.sh
