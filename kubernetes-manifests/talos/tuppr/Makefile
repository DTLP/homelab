VERSION ?= 0.0.47
OUTPUT ?= upstream/tuppr.yaml
NAMESPACE ?= talos

get-upstream:
	helm template tuppr oci://ghcr.io/home-operations/charts/tuppr \
		--version $(VERSION) \
		--namespace $(NAMESPACE) | \
		grep -v 'helm.sh/chart:' | \
		grep -v 'app.kubernetes.io/instance:' | \
		grep -v 'app.kubernetes.io/version:' | \
		grep -v 'app.kubernetes.io/managed-by:' | \
		grep -v '^# Source:' \
		> $(OUTPUT)

