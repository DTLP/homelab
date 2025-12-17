VERSION ?= v1.19.2
NAMESPACE ?= kube-system

.PHONY: get-upstream
get-upstream:
	curl -L https://github.com/cert-manager/cert-manager/releases/download/$(VERSION)/cert-manager.yaml \
		| sed -E 's|(\s*)namespace: "?cert-manager"?|\1namespace: "$(NAMESPACE)"|g' \
		> upstream/cert-manager.yaml
