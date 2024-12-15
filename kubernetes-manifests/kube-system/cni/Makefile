.DEFAULT_GOAL := get-upstream

.PHONY: get-upstream
get-upstream:
	curl -Ls \
		https://docs.projectcalico.org/manifests/calico.yaml \
		> upstream/calico.yaml
