VERSION ?= 1.13.0
NAMESPACE ?= longhorn-system
KUBE_VERSION ?= 1.37.2

.PHONY: get-upstream

get-upstream:
	helm repo add longhorn https://charts.longhorn.io >/dev/null 2>&1 || true
	helm repo update longhorn
	helm template longhorn longhorn/longhorn \
		--version $(VERSION) \
		--kube-version $(KUBE_VERSION) \
		--namespace $(NAMESPACE) \
		--values values.yaml \
		> upstream/longhorn.yaml
