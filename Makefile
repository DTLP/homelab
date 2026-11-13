SHELL=/usr/bin/env bash

# Forward Proxmox provisioning targets to the ansible Makefile.
.PHONY: start stop cluster nvme ssh reboot shutdown ubuntu upgrade check dry-run
start upgrade stop cluster nvme ssh reboot shutdown ubuntu check dry-run:
	$(MAKE) -C ansible $@

hooks-install:
	-rm .git/hooks/pre-commit
	(cd .git/hooks/ && ln -s ../../scripts/pre-commit pre-commit)

bootstrap:
	./scripts/bootstrap.sh
