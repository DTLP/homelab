.DEFAULT_GOAL := get-upstream
.PHONY: get-upstream

VERSION=v1.18.0

get-upstream:
	curl -Ls https://github.com/kyverno/kyverno/releases/download/${VERSION}/install.yaml \
	> upstream/install.yaml
