TALENV := talenv.yaml
NODES := 192.168.0.30 192.168.0.31 192.168.0.32 192.168.0.40 192.168.0.41 192.168.0.42 192.168.0.43

.PHONY: upgrade-k8s upgrade-talos

upgrade-k8s:
	@KUBERNETES_VERSION=$$(grep '^KUBERNETES_VERSION' $(TALENV) | cut -d ':' -f2 | tr -d ' ') && \
	talosctl upgrade-k8s --to $$KUBERNETES_VERSION -n 192.168.0.30

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
