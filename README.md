# Registry cache proxy

A small sidecar for the registry mirror. It reads the tags already cached on
disk and proxies the rest to the upstream registry.

This is **its own git repository**, not part of the homelab repo. It appears
under `kubernetes-manifests/registry/resources` as a git submodule so the
source is visible next to the manifests that use it.

The source of truth lives in Forgejo:
<https://git.dtlp.cc/dtlp/registry-cache-proxy>.

## Builds

CI builds and pushes the image on every push to `main` in Forgejo, using the
local Actions runner:

```
registry.dtlp.cc/library/registry-cache-proxy:sha-<commit>
registry.dtlp.cc/library/registry-cache-proxy:latest
```

The workflow lives in `.forgejo/workflows/build.yaml` and needs two repository
secrets:

| Secret | Value |
| ------ | ----- |
| `REGISTRY_USERNAME` | registry user |
| `REGISTRY_PASSWORD` | registry password |

The registry mirror StatefulSet in `kubernetes-manifests/registry` pulls this
image.

## Local build

```
docker build -t registry.dtlp.cc/library/registry-cache-proxy:dev .
```
