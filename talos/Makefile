TALENV := talenv.yaml
NODES := 192.168.0.30 192.168.0.40 192.168.0.41 192.168.0.42 192.168.0.43
HOSTS := master-0 worker-0 worker-1 worker-2 worker-3

.PHONY: help genconfig apply-config sync upgrade-k8s upgrade-talos

help:
	@echo "Talos cluster management targets"
	@echo ""
	@echo "  genconfig                  Regenerate machine configs (talhelper genconfig)"
	@echo "  apply-config [NODE=...]    Apply config to nodes. NODE accepts an IP or hostname;"
	@echo "                             omit NODE to apply to all nodes."
	@echo "  sync                       genconfig + apply-config"
	@echo "  upgrade-k8s                Upgrade Kubernetes control plane to KUBERNETES_VERSION"
	@echo "                             (DRY_RUN=1 to dry run first)"
	@echo "  upgrade-talos              Upgrade nodes to TALOS_VERSION, skipping nodes already on it"
	@echo ""
	@echo "apply-config options:"
	@echo "  make apply-config                     apply to all nodes"
	@echo "  make apply-config NODE=master-0       apply to one node by hostname"
	@echo "  make apply-config NODE=192.168.0.30   apply to one node by IP"

genconfig:
	@talhelper genconfig

apply-config:
	@[ -z "$(NODE)" ] || echo "==> applying to node $(NODE) only"; \
	for pair in $(join $(addsuffix =,$(NODES)),$(HOSTS)); do \
		node=$${pair%%=*}; host=$${pair#*=}; \
		if [ -n "$(NODE)" ] && [ "$$node" != "$(NODE)" ] && [ "$$host" != "$(NODE)" ]; then \
			continue; \
		fi; \
		file=clusterconfig/homelab-$$host.yaml; \
		if [ -f "$$file" ]; then \
			echo "==> applying config to $$node ($$host)"; \
			talosctl apply-config -n $$node -f $$file; \
		else \
			echo "==> skipping $$node: no config file $$file"; \
		fi; \
	done

sync: genconfig apply-config

upgrade-k8s:
	@KUBERNETES_VERSION=$$(grep '^KUBERNETES_VERSION' $(TALENV) | cut -d ':' -f2 | tr -d ' ') && \
	DRY=$$([ -n "$(DRY_RUN)" ] && echo --dry-run || true) && \
	talosctl upgrade-k8s --to $$KUBERNETES_VERSION -n 192.168.0.30 $$DRY

upgrade-talos:
	@TALOS_VERSION=$$(grep '^TALOS_VERSION' $(TALENV) | cut -d ':' -f2 | tr -d ' ') && \
	for node in $(NODES); do \
		current=$$(talosctl version --short -n $$node 2>/dev/null | grep -A3 '^Server:' | grep 'Tag:' | tr -d ' ' | cut -d ':' -f2); \
		if [ "$$current" = "$$TALOS_VERSION" ]; then \
			echo "skipping node $$node. already on $$TALOS_VERSION"; \
		else \
			echo "upgrading node $$node to $$TALOS_VERSION"; \
			talosctl upgrade --drain-timeout=10m -n $$node --image ghcr.io/siderolabs/installer:$$TALOS_VERSION; \
		fi; \
	done
