# Registry cache proxy

The `registry-cache-proxy.py` script and `Dockerfile` in this directory are for
testing purposes only. They are not built or published by CI.

The image is built and pushed to the local registry manually:

```bash
docker build -t registry.dtlp.cc/library/registry-cache-proxy:0.1.0 .
docker push registry.dtlp.cc/library/registry-cache-proxy:0.1.0
```
