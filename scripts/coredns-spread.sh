#!/usr/bin/env bash
# Talos owns the CoreDNS deployment, so re-apply the required anti-affinity
# after a Talos upgrade or when both replicas land on the same node.
set -euo pipefail

kubectl -n kube-system patch deployment coredns --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/affinity/podAntiAffinity","value":{"requiredDuringSchedulingIgnoredDuringExecution":[{"labelSelector":{"matchExpressions":[{"key":"k8s-app","operator":"In","values":["kube-dns"]}]},"topologyKey":"kubernetes.io/hostname"}]}}
]'
