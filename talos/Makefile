TALENV := talenv.yaml

.PHONY: upgrade-k8s

upgrade-k8s:
	KUBERNETES_VERSION=$$(grep '^KUBERNETES_VERSION' $(TALENV) | cut -d ':' -f2 | tr -d ' ') && \
	talosctl upgrade-k8s --to $$KUBERNETES_VERSION -n 192.168.0.30
