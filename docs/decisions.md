# Decisions

The choices behind this cluster and the reasons for them. The primary audience
is the LLMs that help with the lab, with me as the second reader.

Each entry records the decision, the reason, and what would justify revisiting
it. If a change would contradict an entry, name it and explain why before making
the change. Procedures live in the README or a skill; this file records
decisions.

## Architecture

### One control plane

**Decision.** Run a single Talos control plane, `master-0`.

**Why.** Three control planes with a VIP exceeded the memory and disk budget of
the five 8GB hosts. Memory pressure and slow etcd fsync on three nodes caused
frequent API outages and alert noise. The hardware could not carry the
availability model, so performance won.

**Tradeoff.** No control plane redundancy. Recovery is rebuilding the cluster
from this repository, which has been done several times when Proxmox, Ceph, and
Talos experiments went wrong. Restoring a recent `make etcd-snapshot` is the
faster alternative when one exists; `make upgrade-k8s` takes one before each
Kubernetes upgrade.

**Revisit if.** Host memory or disk performance changes, or etcd latency becomes
a problem again.

### Keep the 100 Mbps switch

**Decision.** Keep the TP-Link TL-SF1008D and run everything over it.

**Why.** It is adequate for actual lab traffic, including image pulls, and it
was cheap. No workload has been abandoned because of network throughput.

**Tradeoff.** Throughput is capped at roughly 12 MB/s per link. Accepted
because nothing in the lab needs more.

**Revisit if.** Image pulls, backups, or Longhorn replication start saturating
the link.

### Four workers, one Kubernetes VM per host

**Decision.** Run one control plane and four workers, one Kubernetes VM per host
in host order: `master-0` on pve1, then `worker-0` through `worker-3` on pve2 to
pve5. The Forgejo runner VM is the one exception and shares pve1 with `master-0`.

**Why.** Five hosts with 4 vCPUs and 8GB of RAM each cannot carry more. This is
the largest split the hardware allows while keeping each Kubernetes VM on its
own host and leaving room for the runner.

**Tradeoff.** Any maintenance on `master-0` takes the Kubernetes API down.
Accepted because the lab tolerates downtime and rebuilding is cheap.

**Revisit if.** A host is added, or the VMs can take more memory.

### One flat network, no VLANs

**Decision.** Put everything on `192.168.0.0/24` with no segmentation.

**Why.** A flat network keeps Proxmox, Talos, MetalLB and DNS simple. The lab
sits on a trusted LAN, and the router and host firewalls provide the boundary.

**Tradeoff.** Devices on the main LAN can reach the lab's services. Network
policies only isolate pods from each other.

**Revisit if.** The lab starts hosting traffic from people or devices that are
not trusted, or I want a more sophisticated network for its own sake.

### No VM snapshots or backups

**Decision.** Treat the VMs as cattle, not pets: take no Proxmox snapshots and
keep no VM backups. Rebuild from Git instead.

**Why.** The lab was rebuilt from scratch many times while it was being built,
so the path is well exercised. It has matured enough that a full rebuild is now
rare. A snapshot is a second source of truth that drifts from the repository
without anyone noticing.

**Tradeoff.** A bad change costs a rebuild rather than a rollback, and there is
no way to recover a VM in the state it was in yesterday. Etcd snapshots are the
exception: they capture control-plane data, not a VM image, and make recovery
faster.

## Storage

### Longhorn as the storage platform

**Decision.** Run every PersistentVolume on Longhorn, with two replicas per
volume on the workers' local disks.

**Why.** Longhorn replaced the NFS VM, which was a single point of failure, and
gives each volume a real size limit. The next closest alternative, Ceph, is far
more resource-hungry and operationally heavy than this small lab justifies.

**Tradeoff.** There is no dedicated disk: both replicas live on the workers'
system disks, so Longhorn survives a node failure but not a disk failure.
Capacity is whatever remains after the system disk reservation.

**Revisit if.** Dedicated disks are added, disk-failure tolerance becomes a
requirement, or I add external storage such as a NAS.

### Treat persistent data as disposable

**Decision.** Do not back up the Longhorn volumes.

**Why.** Configuration and secrets live in Git, and the volumes hold metrics,
logs, dashboard state, and certificate material, all of which the cluster or
cert-manager can recreate. Losing them costs history, not capability.

**Tradeoff.** Losing a volume loses its history, and there is no backup to
restore. Forgejo is the only exception: its volume holds repositories, so losing
it costs more than history. Accepted because they can be rebuilt and the chance
of loss is low enough.

## Delivery

### Calico as the only CNI

**Decision.** Disable Flannel on every node with the Talos `cni-none` patch and
run Calico.

**Why.** Calico is the CNI used at work, and network policy support is a
requirement rather than a nice-to-have. Flannel is simpler but offers less.

**Tradeoff.** More components to run than Flannel. Accepted for the policy
support and the familiarity.

### `bootstrap.sh` is for a rebuild only

**Decision.** Install the platform, ArgoCD, Flux and the workloads with one
script, applied in dependency order, and run it only after the cluster has been
rebuilt from scratch.

**Why.** A single ordered script means a fresh cluster reaches GitOps with no
manual steps. Applying it to a running cluster would fight ArgoCD, which owns
the same resources afterwards.

**Tradeoff.** Day-to-day changes never go through the script, so it can rot
between rebuilds. There is no regular rebuild that would catch the drift; the
script is reviewed occasionally and updated on a best-effort basis.

### `make` as the interface

**Decision.** Expose the common operations, such as start, stop, bootstrap,
configuration generation and upgrades, as `make` targets.

**Why.** One entry point hides the tool-specific commands and makes the
runbook obvious. It also gives an agent a small set of safe commands to run
instead of assembling raw `talosctl`, `ansible-playbook` and `terraform`
invocations.

**Tradeoff.** The Makefile becomes a dependency a reader has to check. Accepted
for the consistency.

### ArgoCD by default, Flux in `sandbox` only

**Decision.** Manage Kubernetes resources with ArgoCD in every namespace except
`sandbox`, which Flux owns.

**Why.** ArgoCD is the tool used at work, and the lab gives another place to
practise it. Flux stays because a second controller is worth hands-on exposure,
and `sandbox` is the experimental namespace by design.

**Tradeoff.** Two reconciliation models to reason about. Accepted as a
deliberate learning exception.

### terraform-applier for one module

**Decision.** Automate Terraform with `terraform-applier`, currently only for
the Grafana dashboards workspace.

**Why.** The tool is developed by the team at work. Running it here dogfoods it
and keeps familiarity with it, even though the lab has few Terraform workloads
that benefit from scheduled applies.

**Tradeoff.** One tool for one module. Accepted because the value is dogfooding
rather than efficiency.

### Per-namespace Applications, no root Application

**Decision.** Apply one `argocd-app.yaml` per namespace manually, rather than
managing them with a root Application or ApplicationSet.

**Why.** Each namespace belongs to a different team and opts into ArgoCD by
applying its own Application once. This is the model I would use in production,
with teams subscribing to ArgoCD themselves. Alerting reports out-of-sync
Applications, and a high push volume means problems surface quickly.

**Tradeoff.** Nothing reconciles the Applications themselves. A deleted
Application has to be noticed by a person and reapplied, and the live count can
differ from the repository without any alert. A root Application or
ApplicationSet would close the gap at the cost of an extra layer and the risk of
a bad prune.

**Revisit if.** The drift becomes a recurring problem.

### Upgrade on demand, from a dependency dashboard

**Decision.** Let Renovate track dependency updates, but create no branches or
pull requests until one is approved from the Dependency Dashboard issue. Upgrade
Talos, Kubernetes, and manifests when it suits, usually with an agent doing the
work.

**Why.** Renovate's default push model produced more pull requests than the lab
justified. Approval inverts it: the dashboard lists what is behind, and ticking
an entry starts a pull request when there is time for it. An agent can then read
the changelog, plan the upgrade order, check application health before the
upgrade, run it, watch health afterwards, report back, and commit the changes.
Rollback is reverting the commit.

**Tradeoff.** The dashboard only shows what Renovate detects, so it is not a
complete inventory. Entries can sit for weeks, and the lab still drifts behind
current versions. An approved update is a normal pull request that needs review.
Skipping versions usually means stepping through the intermediate releases; a
direct jump is fine when the upstream supports it.

**Revisit if.** The dashboard becomes noise itself, or upgrades slip because
nobody opens it.

### Terraform state in HCP Terraform

**Decision.** Store all workspace state remotely in HCP Terraform.

**Why.** It matches a production-like setup, and the lab is always online when
work happens.

**Tradeoff.** Rebuilding the lab depends on internet access, and state contains
sensitive values such as Proxmox credentials and cluster secrets. Accepted
because the value is in using a hosted backend like production, not because
self-hosting is difficult.

**Revisit if.** The lab must be rebuilt without internet access, or HCP
Terraform is unavailable when work must happen.

### Pin images by digest

**Decision.** Reference container images by digest, with a `# vX.Y.Z` comment
naming the version.

**Why.** Tags move and digests do not, so the cluster runs exactly the image
that was tested. The comment keeps the version readable without trusting the
tag.

**Tradeoff.** Re-rendering an upstream chart brings its tags back, so pin the
digests again after a re-render.

### Kustomize over Helm

**Decision.** Manage manifests with Kustomize. Use Helm only to render a
vendor's chart when there is no other distribution, commit the rendered output,
and continue with Kustomize patches from there.

**Why.** One templating model across the repo is easier to read, diff and patch
than a mix of charts and overlays. Rendering the chart once makes the result
reviewable in Git instead of hidden behind values. Helm is avoided wherever the
project also ships plain manifests or a Kustomize base.

**Tradeoff.** Upstream chart changes do not arrive automatically. A `make`
target fetches a chart's manifests into the namespace's `upstream/` directory,
and the chart version is pinned by changing the tag or commit SHA by hand before
pulling. New versions need a manual re-render and diff.

### Terraform for VMs, Ansible for hosts

**Decision.** Use Terraform to create the Talos VMs. Use Ansible to
build the Proxmox cluster, set up SSH, mount the NVMe disks, deploy the Ubuntu
cloud image, and handle shutdown and upgrades.

**Why.** A host cannot be built from nothing with Terraform, and the operational
tasks, such as powering the lab off, are Ansible's shape rather than
Terraform's. Terraform handles the resources it can create cleanly.

**Tradeoff.** Two tools with a boundary to remember, and host-level changes are
invisible to Terraform state.

### Registry cache for `docker.io` only

**Decision.** Run a pull-through cache for `docker.io`, and pull `quay.io` and
`ghcr.io` directly.

**Why.** The cache was built to try the pattern, not because pulls were slow.
Mirroring every registry would mean one more mirror per upstream for no gain.

**Tradeoff.** Two registries do not benefit from the cache. Accepted.

### `sandbox` is for disposable experiments

**Decision.** Keep `sandbox` as Flux's domain, holding apps that are there to be
tried rather than relied on.

**Why.** Some workloads need somewhere to live without earning a place in the
platform. Flux keeps that space a genuine alternative to ArgoCD.

**Tradeoff.** Anything in there can vanish or break without ceremony.

## Repository

### Public by default

**Decision.** Keep the repository public.

**Why.** Working in the open is the point. Open source is better when the work
is visible, and being watched makes every commit something to think twice about,
which raises the quality of the lab.

**Tradeoff.** The topology and configuration are visible to anyone. That is
uncomfortable, and accepted. The Git history has been scanned for secrets.

### Archive instead of delete

**Decision.** Move retired configuration to `archive/` rather than deleting it.

**Why.** It might come back in a new shape, get reused, or be useful to someone
else. Some of it is also hard to throw away.

**Tradeoff.** The repository carries dead code. Keeping it under `archive/` makes
its status clear, at the cost of space and search noise.

### Minimal CI

**Decision.** CI only renders Kustomize diffs of changed manifests on pull
requests. No linting, schema validation, or cluster checks.

**Why.** I am the only person working here and rarely open a pull request, so CI
should stay light. When a pull request is used, the diff is the check that
matters; linting is not worth the noise until a real problem calls for it.

**Tradeoff.** Most changes go straight to main, where CI does not run, so schema
errors are caught at sync instead.

## Secrets

### Secrets encrypted in Git

**Decision.** Keep every secret in the repository, encrypted with age through
Strongbox. A Git clean/smudge filter encrypts on commit and decrypts on
checkout, and a pre-commit hook refuses unencrypted secret files. Secret values
never appear in manifests: put them under the namespace's `secrets/` directory
and generate the Kubernetes Secret with a Kustomize `secretGenerator`.

**Why.** The repository stays the single source of truth, including for
credentials, with no separate secret store to keep available.

**Tradeoff.** A clone needs Strongbox and the age identity before checkout or
commit works.

## Security

### PodSecurity and the pod baseline

**Decision.** Keep Pod Security Admission at `privileged` with no namespace
labels. The pod baseline is enforced by the native admission policies below.

**Why.** PSA's namespace labels were too coarse for this cluster: they either
blocked privileged system components or allowed everything. The native policies
express the same rules with a small set of named workload exceptions.

**Tradeoff.** The cluster relies on the policies being correct and applied, with
no second layer from PSA.

**Revisit if.** A namespace needs a boundary the policies cannot express.

### Native admission policies

**Decision.** Enforce the pod baseline with Kubernetes' native admission
policies: `ValidatingAdmissionPolicy` for privileged pods, host namespaces and
host paths, and a `MutatingAdmissionPolicy` for Linux user namespaces. Resource
requests and limits are required in Deny mode. Kyverno is no longer installed.

**Why.** The native policies cover what this cluster needs without running and
maintaining a policy engine. The exceptions stay explicit under
`kubernetes-manifests/kube-system/admission-policies/`.

**Tradeoff.** Exceptions can erode the policy. `kube-system` and
`longhorn-system` are exempt because their components are privileged,
chart-managed, or created dynamically.

**Revisit if.** Exceptions start to outnumber enforced workloads.

**Supersedes.** Kyverno with reviewed exceptions.

### Default-deny NetworkPolicies

**Decision.** Apply default-deny NetworkPolicies to every namespace except
`kube-system`, which stays open.

**Why.** It mirrors a production posture and forces each workload's traffic to
be declared.

**Tradeoff.** `kube-system` stays permissive because the CNI runs there and
needs broad access to pod networking.

## Observability

### Prometheus, Loki and Grafana

**Decision.** Use the Prometheus stack for metrics, Loki for logs and Grafana for
dashboards, with Alertmanager sending to Slack.

**Why.** It is a common stack, so the practice transfers. Alerts exist for
awareness during a session and for practising alert design, not for paging.

**Tradeoff.** None considered. Alternatives would be worth exploring only if the
stack stops fitting the lab or becomes a maintenance burden.

### Alerts go to Slack

**Decision.** Send in-cluster alerts to Slack.

**Why.** Slack is only reachable while the lab is up, which matches the lab's
uptime and the purpose of its alerts.

**Tradeoff.** Nothing pages when the lab is down. Accepted because there is no
uptime expectation.

### Agent access through MCP where it helps

**Decision.** Run `mcp-grafana` in the cluster so agents can query dashboards.
Do not run a Kubernetes MCP server.

**Why.** Grafana's API is not something an agent can use from the shell, so the
MCP server earns its place and works well. Kubernetes access is already covered
by the local `kubectl`, which the agents can call directly.

**Tradeoff.** One more component to keep running. Without the Grafana MCP, an
agent would have to use the raw Grafana API; Kubernetes needs no MCP because
`kubectl` already covers it.

## Access and operation

### One wildcard certificate

**Decision.** Issue one `*.dtlp.cc` wildcard through cert-manager with a
Cloudflare DNS-01 challenge, store it in the `certs` namespace, and let Traefik
reuse it for every `IngressRoute`.

**Why.** One certificate covers every UI and API, so adding a hostname needs no
new certificate and no per-ingress issuance. DNS-01 works without exposing
anything to the internet.

**Tradeoff.** A failed renewal breaks TLS everywhere at once. It is noticed by
the certificate expiry alert and in a browser, but only while the lab is powered
on.

### Private-only ingress

**Decision.** Serve `*.dtlp.cc` from MetalLB on the LAN only. Forward no ports.
Leave the Kubernetes lab without remote access.

**Why.** Nothing in the cluster needs to be reachable from outside the house.
Anything that does, such as Pangolin, Ente Photos, and mail, runs on the Hetzner
host instead.

**Tradeoff.** The lab is unusable while away from home, which is consistent with
it being powered off then. Certificates for the lab are best effort; a failed
renewal is noticed by the alert and in a browser, but only while the lab is up.
Public certificates on Hetzner have real monitoring and page over Telegram.

### Power off when away

**Decision.** Shut the lab down overnight and while travelling.

**Why.** Electricity cost outweighs the value of a cluster nobody is using.

**Tradeoff.** There is no uptime expectation, so in-cluster alerts only matter
while the lab is up. Alerts go to Slack for awareness during a session and to
practise alert design, not to page anyone.

### Proxmox cluster without HA

**Decision.** Run the five hosts as one Proxmox cluster and rely on quorum
rather than HA groups.

**Why.** Quorum keeps the cluster manageable when a host dies or gets stuck,
which is the failure that actually happens. Automatic VM restart is not worth
the extra moving parts for a lab that is powered off half the time.

**Tradeoff.** A dead host takes its VM down until it is dealt with by hand.
Accepted because the rebuild path is already practised.

### No HPAs, and one PDB

**Decision.** Run no HorizontalPodAutoscalers. The only PodDisruptionBudget is
Calico's `calico-kube-controllers`, inherited from the upstream manifest.

**Why.** Almost every workload runs a single replica, so autoscaling has
nothing to scale and a PDB either does nothing or blocks a node drain. The
Calico PDB has `maxUnavailable: 1` against one replica, so it does not
constrain drains. It is kept because it comes from upstream and becomes
meaningful if that controller is scaled.

**Tradeoff.** Draining a node takes single-replica workloads down. Accepted at
this size.

**Revisit if.** A workload gains replicas or an uptime requirement.
