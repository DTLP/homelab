#!/usr/bin/env bash
#
# Bootstrap the Kubernetes workloads on a freshly provisioned Talos cluster.
#
# A fresh `terraform apply` brings the cluster up with the Talos-managed
# Flannel CNI disabled (see terraform/proxmox/k8s/resources/cni-none-patch.yaml).
# This script then installs the platform manifests in dependency order,
# including ArgoCD and Flux, so a fresh cluster needs no manual steps before
# GitOps takes over. Each namespace ships a default-deny NetworkPolicy with
# explicit allows for DNS, the API server, monitoring, and ingress.
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
  shift
  echo "==> kubectl apply -k $dir $*"
  "${KUBECTL[@]}" apply -k "$dir" "$@"
}

apply_file() {
  local file="$1"
  shift
  echo "==> kubectl apply -f $file"
  "${KUBECTL[@]}" apply "$@" -f "$file"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTS="$ROOT/kubernetes-manifests"

# 1. Pod networking and policy enforcement must exist before any workload is
# scheduled.
apply "$MANIFESTS/kube-system/cni" -n kube-system

# 2. Create every namespace before applying anything namespaced.
apply_file "$MANIFESTS/kube-system/namespaces.yaml"

# 3. Platform services that the rest of the stack depends on.
apply "$MANIFESTS/metallb-system" -n metallb-system
apply "$MANIFESTS/kube-system/cert-manager" -n kube-system
apply "$MANIFESTS/kube-system/external-dns" -n kube-system
apply "$MANIFESTS/kube-system/metrics-server" -n kube-system
apply "$MANIFESTS/kube-system/coredns" -n kube-system

# 4. Ingress and the wildcard certificate.
apply "$MANIFESTS/ingress-controller" -n ingress-controller
apply "$MANIFESTS/certs" -n certs

# 5. Policy and RBAC controllers.
apply "$MANIFESTS/kube-system/kyverno" -n kube-system
apply "$MANIFESTS/kube-system/terraform-applier" -n kube-system

# 6. ArgoCD. It must exist before any directory with an Application object is
# applied, because those objects need its Application CRD. Its CRDs are larger
# than the client-side apply annotation limit, so use server-side apply. When
# migrating an existing cluster from client-side apply, add --force-conflicts
# once to take over the fields.
apply "$MANIFESTS/argocd" -n argocd --server-side

# 7. Flux. It must exist before the sandbox Kustomization is applied.
apply "$MANIFESTS/flux-system" -n flux-system

# 8. Workloads. Each directory creates its Application object as well, so
# ArgoCD takes over reconciliation after the first apply.
apply "$MANIFESTS/monitoring" -n monitoring
apply "$MANIFESTS/nfs-provisioner" -n nfs-provisioner
apply "$MANIFESTS/terraform-applier" -n terraform-applier
apply "$MANIFESTS/registry" -n registry
apply "$MANIFESTS/git" -n git
apply "$MANIFESTS/kafka" -n kafka
apply "$MANIFESTS/sandbox" -n sandbox

# 9. The kube-system Application and NetworkPolicies.
apply_file "$MANIFESTS/kube-system/argocd-app.yaml" -n kube-system
apply_file "$MANIFESTS/kube-system/network-policies.yaml" -n kube-system

echo "==> Bootstrap complete."
