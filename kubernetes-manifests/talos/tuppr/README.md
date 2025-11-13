# Upgrading Talos and Kubernetes with tuppr

https://github.com/home-operations/tuppr

Allow Talos API access to the desired namespace by applying this config to all master nodes:
```yaml
machine:
  features:
    kubernetesTalosAPIAccess:
      allowedKubernetesNamespaces:
        - talos
      allowedRoles:
        - os:admin
      enabled: true
```

### Monitoring Upgrades

```bash
# Watch Talos upgrade progress
kubectl get talosupgrade -w

# Watch Kubernetes upgrade progress
kubectl get kubernetesupgrade -w

# Check detailed status
kubectl describe talosupgrade cluster-upgrade
kubectl describe kubernetesupgrade kubernetes

# View upgrade logs
kubectl logs -f deployment/tuppr -n talos

# Check metrics endpoint
kubectl port-forward -n talos deployment/tuppr 8080:8080
curl http://localhost:8080/metrics | grep tuppr_
```

### Suspending Upgrades

Suspending upgrades can be useful if you want to upgrade manually and not have the controller interfere.

```bash
# Suspend Talos upgrade
kubectl annotate talosupgrade cluster-upgrade tuppr.home-operations.com/suspend="true"

# Suspend Kubernetes upgrade
kubectl annotate kubernetesupgrade kubernetes tuppr.home-operations.com/suspend="true"

# Remove the suspend annotation to resume
kubectl annotate talosupgrade cluster-upgrade tuppr.home-operations.com/suspend-
kubectl annotate kubernetesupgrade kubernetes tuppr.home-operations.com/suspend-
```

### Troubleshooting

```bash
# Reset failed Talos upgrade
kubectl annotate talosupgrade cluster-upgrade tuppr.home-operations.com/reset="$(date)"

# Reset failed Kubernetes upgrade
kubectl annotate kubernetesupgrade kubernetes tuppr.home-operations.com/reset="$(date)"

# Check job logs
kubectl logs job/tuppr-xyz -n talos

# Check controller health
kubectl get pods -n talos -l app.kubernetes.io/name=tuppr

# View metrics for debugging
kubectl port-forward -n talos deployment/tuppr 8080:8080
curl http://localhost:8080/metrics | grep -E "(tuppr_.*_phase|tuppr_.*_duration)"
```

### Emergency Procedures

```bash
# Pause all upgrades (scale down controller)
kubectl scale deployment tuppr --replicas=0 -n talos

# Emergency cleanup
kubectl delete talosupgrade --all
kubectl delete kubernetesupgrade --all
kubectl delete jobs -l app.kubernetes.io/name=talos-upgrade -n talos
kubectl delete jobs -l app.kubernetes.io/name=kubernetes-upgrade -n talos

# Resume operations
kubectl scale deployment tuppr --replicas=1 -n talos
```
