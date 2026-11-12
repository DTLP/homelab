# Registry cache proxy

A small sidecar for the registry mirror. It reads the tags already cached on
disk and proxies the rest to the upstream registry.

The source of truth lives in Forgejo:
<https://git.dtlp.cc/dtlp/registry-cache-proxy>. This directory is kept in sync
with `git subtree`, so the code is also readable here, next to the manifests
that use it.

## Builds

CI builds and pushes the image on every push to `main` in the Forgejo repo,
using the local Actions runner:

```
registry.dtlp.cc/library/registry-cache-proxy:sha-<commit>
registry.dtlp.cc/library/registry-cache-proxy:latest
```

The workflow lives in `.forgejo/workflows/build.yaml` in that repo and needs
two repository secrets:

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

## Syncing with Forgejo

```
# pull changes made in Forgejo
git subtree pull \
  --prefix=kubernetes-manifests/registry/resources/registry-cache-proxy \
  https://git.dtlp.cc/dtlp/registry-cache-proxy.git main --squash

# send changes made here back to Forgejo
git subtree push \
  --prefix=kubernetes-manifests/registry/resources/registry-cache-proxy \
  https://git.dtlp.cc/dtlp/registry-cache-proxy.git main
```
