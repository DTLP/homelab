CALICO_VERSION := v3.32.1

.PHONY: get-upstream
get-upstream:
	curl -Ls \
		https://raw.githubusercontent.com/projectcalico/calico/$(CALICO_VERSION)/manifests/calico.yaml \
		> upstream/calico.yaml
