---
name: homelab-upgrade
description: Use when the user asks you to review or prepare a dependency upgrade for rollout, with or without a Renovate/upgrade PR — typically by sending a PR link (e.g. DTLP/homelab/pull/N), a version bump, or an upgrade of any component in the homelab (Talos, Kubernetes, Terraform providers, Kubernetes apps, CI actions, etc.). Triggers on words like "upgrade", "upgrade PR", "renovate PR", "review PR", "bump", or a github.com/DTLP/homelab/pull/ link.
---

# Upgrade review and rollout

When asked to review an upgrade of any component, walk through it before it is
merged or applied. Apply the same process regardless of the component type:
Talos, Kubernetes versions, Terraform providers, Kubernetes apps, GitHub
Actions, or anything else.

## 1. Understand the change

- Read the PR title, body, and changed files (or the requested version bump).
- Identify the component, how it is tracked (docker image, kustomize,
  terraform provider, github-actions, regex pin, etc.), the current (live)
  version, and the target version.
- For grouped upgrades, note that one version bump may apply across several
  places/images and must be updated consistently.

## 2. Check changelogs between live and target versions

- Look up the project's changelog, release notes, migration guides, or upstream
  docs — on GitHub or wherever the project publishes them.
- Read everything between the live version and the target version.
- Flag breaking changes, migration steps, deprecations, and config/schema
  changes that affect how the component is used.
- Check component-specific upgrade paths: CRD/schema/flag changes for
  Kubernetes manifests, provider resource renames for Terraform, upgrade
  ordering/gates for Talos and Kubernetes, etc.

## 3. Verify all necessary changes are included

- Confirm the version is bumped everywhere it appears and that any required
  supporting changes (config, manifests, CRDs, RBAC, flags, resources,
  dependencies) are present in the PR or still need to be made.
- Recommend any additional edits that are required but missing.

## 4. Work on a branch, not main

- If the upgrade has a PR, check out its branch (e.g.
  `git fetch origin refs/pull/N/head:pr-N && git checkout pr-N`) rather than
  editing `main` directly. For a clean Renovate bump there is usually nothing
  to edit — the checkout is used to run validation from the branch context.
- If there is no PR, create a branch for the upgrade, or work on the current
  branch if the user prefers. The rest of the process is the same.
- If anything needs to be added or changed, update the PR branch and commit it.
  Push only when the user explicitly asks; otherwise keep the commit local. Do
  not touch `main` unless explicitly asked.
- For Kubernetes apps deployed by ArgoCD, a pre-merge cluster test is valid when
  auto-sync is off: apply the local manifests manually and test. See section 5.
- When the PR is ready, merge it on GitHub with **squash and merge** (the repo's
  default merge method for upgrade PRs) via `gh pr merge N --squash`.
- Git commit/push/stash/checkout are configured as `ask` in the user's global
  opencode config. Push only when the user explicitly asks. Confirm the merge
  method before merging.

## 5. Test the release

- Use the component's normal validation and deployment workflow (build/render,
  lint, plan, apply, or deploy commands relevant to the component).
- Prefer the repo's CI checks and diff/plan tooling to catch schema and config
  errors before rollout.
- Follow the component's documented upgrade procedure and note any manual or
  sequential steps (e.g. Talos upgrade order, provider state migration).
- Check compatibility with the running infrastructure (e.g. confirm the Talos
  version supports the target Kubernetes version via the support matrix).

### Kubernetes apps: ArgoCD GitOps rollout

- `kubernetes-manifests/` is normally deployed by ArgoCD. Each namespace's
  `argocd-app.yaml` tracks `main` with `automated.selfHeal: true`,
  `prune: true`, `ApplyOutOfSyncOnly`, and `ServerSideApply`.
- Check the live Application first: auto-sync is sometimes paused, and every
  app can be set to manual. With auto-sync off there is no self-heal, so
  applying the local manifests manually and testing on the cluster is a valid
  path: `kubectl -n <ns> apply -k <dir>`. Use this when the user wants to test
  a change before pushing it.
- With auto-sync on, a pre-merge rollout is not the normal workflow. Manually
  applying a PR-branch manifest drifts from `main`, and ArgoCD self-heals it
  back on the next sync. If a pre-merge rollout is still needed, point a
  temporary Application at the PR head (`targetRevision` = PR head SHA) or
  pause auto-sync/selfHeal for that app, then restore it afterwards.
- A manual rollout is not tracked in git. If the change is not merged, either
  restore the previous state or keep auto-sync off until it lands.
- Before merging, validate from the PR branch: `kustomize build <dir>` renders
  cleanly (also covered by the manifest-diff CI check), and for app configs
  use the upstream validation path (e.g. `docker run grafana/loki:NEW
  -config.file=... -verify-config=true`).
- When applying manifests to the live cluster with kubectl, always specify the
  target namespace (`kubectl -n <ns> apply -k <dir>`) because the per-namespace
  manifests do not set a `namespace:` field — omitting `-n` applies the
  resources to the `default` namespace instead.
- After the rollout, manual or GitOps, verify on the live cluster: the workload
  rolled out at the target version (`kubectl -n <ns> get pods -o wide`,
  container image tag, Ready), the app responds, and logs have no errors. For
  GitOps, check the Application is Synced and Healthy. Follow the app's upgrade
  notes (e.g. single-replica StatefulSet means brief downtime; the agent
  buffers and retries).
- If you disable ArgoCD auto-sync for a manual rollout, applying a namespace
  directory that contains its own `argocd-app.yaml` re-enables it. ArgoCD can
  then revert the rollout to `main` within seconds. Re-disable sync in the
  namespace immediately after every apply, or apply the rendered manifests with
  the `Application` object filtered out.
- Upstream kustomize bases can lag the release image (metrics-server and
  external-dns both shipped a new ref that still pointed at the previous image).
  Check the rendered `image:` and pin the release image by digest when it does
  not match.
- A single-replica Deployment with an RWO PVC (Grafana) deadlocks on
  `RollingUpdate`; set `strategy.type: Recreate` so the old pod releases the
  volume before the new one starts.

## 6. Rollout specifics: Talos / Kubernetes control plane

- Kubernetes version bumps for this repo are tracked in `talos/talenv.yaml`
  (`KUBERNETES_VERSION`); `talconfig.yaml` templates it into the machine config.
- Regenerate node configs with `make genconfig` (writes `talos/clusterconfig/`,
  which is gitignored — generated files are not committed).
- Verify the rendered control-plane images (kubelet, kube-apiserver,
  controller-manager, scheduler, kube-proxy) show the target version.
- Validate before applying: `make upgrade-k8s DRY_RUN=1` runs
  `talosctl upgrade-k8s --dry-run`, which reports per-node compatibility.
- Apply with `make upgrade-k8s` (runs `talosctl upgrade-k8s` against the first
  control-plane node). Expect it to bump the control plane, CoreDNS, and prune
  Talos-managed bootstrap manifests (e.g. flannel RBAC when Calico is the CNI).
- Post-upgrade: all nodes `Ready` and at the target version, control-plane pods
  Running, no `NetworkUnavailable`/pressure conditions on nodes.
- Wait for each node to be `Ready` and uncordoned before upgrading the next
  one. The `upgrade-talos` target does this; skipping it lets every
  single-replica pod collect on the one node that is available.
- After the last node, run `make -C talos rebalance`. It triggers a one-shot
  descheduler Job and re-applies the CoreDNS anti-affinity. The
  `upgrade-talos` target runs it automatically. Verify the distribution with
  `kubectl get pods -A -o wide`.
- Re-apply the CoreDNS anti-affinity with `scripts/coredns-spread.sh`. Talos
  owns the deployment and can reset it during an upgrade.
- `make upgrade-talos` skips the drain for every node. Longhorn's
  instance-manager pods cannot be evicted within the drain timeout, and a
  failed drain leaves the node cordoned with the new slot staged but not
  booted. Use `--drain=false`, then uncordon.
- The script waits only for the Talos API to report the target version. The
  Kubernetes API can still be restarting when the next node is processed, so
  cordon/uncordon operations may fail; confirm the API is back before relying
  on node operations.
- Read the installer reference from the live machine config. The config can be
  one escaped YAML line, so extract the full image token rather than a fixed
  field.

## 7. Repo-wide upgrade conventions

These apply to every component, not just Kubernetes.

- **Read the changelog first.** Record breaking changes before anything else,
  then improvements and new features, then suggest changes the upgrade enables.
- **Suggest new features, don't adopt them.** If the release includes something
  that fits this cluster, mention one or two as optional follow-ups, for example
  "Kubernetes now has X; it could replace Y here. Want to try it separately?"
  Keep them out of the upgrade itself and wait for the user to ask.
- **Snapshot before you start.** Note the state of nodes, applications, pod
  distribution, and resource use so you can tell afterwards whether something
  actually changed.
- **Order: control plane first, then workers.** Upgrade `master-0`, verify it,
  then each worker in turn, verifying nodes and pods as they return. Use the
  same order for Kubernetes itself.
- **Verify after, not just during.** Check metrics and logs for errors,
  warnings, and anomalies before reporting back.
- **Never upgrade to a `.0` patch release.** Wait for at least `.1`.
- **Pin images by digest, not tag.** Add a `# vX.Y.Z` comment so the version
  stays readable without depending on the tag.

## Output

Return a concise summary: what changes, breaking or important notes, any
missing required changes, and the test steps taken (or a test plan if not yet
run). Flag anything that should not be merged or applied without manual
attention. Optionally, mention one or two features the upgrade enables, marked
as follow-ups rather than part of this change.
