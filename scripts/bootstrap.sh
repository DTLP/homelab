#!/usr/bin/env bash
#
# Bootstrap the Kubernetes workloads on a freshly provisioned Talos cluster.
#
# A fresh `terraform apply` brings the cluster up with the Talos-managed
# Flannel CNI disabled (see terraform/proxmox/k8s/resources/cni-none-patch.yaml).
# This script then installs the platform manifests, starting with Calico so
# pod networking is in place before any workload starts. Each application
# namespace ships its own NetworkPolicy, so no workload runs unprotected.
#
# Usage:
#   ./scripts/bootstrap.sh            # use the default kubeconfig context
#   ./scripts/bootstrap.sh PATH       # use an explicit kubeconfig
#
set -euo pipefail

KUBECONFIG=${1:-${KUBECONFIG:-}}
KUBECTL=(kubectl)
if [[ -n "$KUBECONFIG" ]]; then
  KUBECTL+=(--kubeconfig "$KUBECONFIG")
fi

apply() {
  local dir="$1"
  echo "==> kubectl apply -k $dir"
  "${KUBECTL[@]}" apply -k "$dir"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$ROOT/kubernetes-manifests"

# Calico first: pod networking and policy enforcement must exist before any
# other workload is scheduled.
apply "$MANIFESTS/kube-system/cni"

# Platform services that the rest of the stack depends on.
apply "$MANIFESTS/metallb-system"
apply "$MANIFESTS/kube-system/cert-manager"
apply "$MANIFESTS/kube-system/external-dns"
apply "$MANIFESTS/kube-system/metrics-server"
apply "$MANIFESTS/kube-system/coredns"

# The ingress controller is the entry point for everything else.
apply "$MANIFESTS/ingress-controller"

# Certificates for the ingress routes.
apply "$MANIFESTS/certs"

# kube-system NetworkPolicies (kube-dns, metrics-server, apiserver flows).
# Applied after the system services exist so the allow rules line up.
apply "$MANIFESTS/kube-system"

# Application workloads. Each namespace ships its own NetworkPolicy
# (default-deny with the known flows), so no workload starts unprotected.
apply "$MANIFESTS/monitoring"
apply "$MANIFESTS/nfs-provisioner"
apply "$MANIFESTS/sandbox"

echo "==> Bootstrap complete."
