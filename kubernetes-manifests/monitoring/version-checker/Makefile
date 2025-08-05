.DEFAULT_GOAL := get-upstream
VERSION := v0.9.3

.PHONY: get-upstream
get-upstream:
	curl -Ls \
		https://raw.githubusercontent.com/jetstack/version-checker/$(VERSION)/deploy/yaml/deploy.yaml | \
		awk 'BEGIN{RS="---\n"; ORS="---\n"} !match($$0, /kind: (Namespace)/) {print}' | \ # Skip Namespace
		grep -v "^  namespace: version-checker" \ # Delete metadata.namespace
		> upstream/version-checker.yaml
