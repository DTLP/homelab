# Setting up Proxmox Cluster

## Prerequisites
- Ansible v2.9.6
- Two or more fresh Proxmox nodes

## How to:
1. Create `secrets/root_password` file containing the password for the `root`
user of your PVE nodes. (Password must be the same on all nodes).
2. Create a new SSH key you're going to use to access PVE nodes and place it in
`secrets/id_ed25519`. Make sure `ssh_setup.yaml` has the correct file name.
3. Verify the content of `inventory.ini` making sure all IP addresses, paths and
variables are set correctly.
4. Run `make cluster` to create Proxmox cluster on the main node and join it
with the rest of the nodes.
5. Run `make ssh` to upload your SSH keys and disable SSH password login.
6. Run `make nvme` to mount an extra NVMe drive on all nodes.
7. Run `make ubuntu` to download Ubuntu Cloud image to all nodes.

Note: You can limit a playbook run to one node.
```
make nvme ARGS="--limit pve4"
```

## Safety

`make start` checks the playbook syntax before it runs anything.

`make dry-run` runs the same playbooks with `--check --diff`, so you can see
what would change without changing a node. It still connects to the nodes: the
read-only probes and `synchronize` run, while tasks that create or modify state
are skipped. A dry run therefore catches templating, condition, and device
mistakes, but it cannot prove that a skipped command would succeed.

Run a changed playbook against one node first before rolling it out:

```
make nvme ARGS="--limit pve4"
```

`nvme_setup.yaml` is safe to re-run. It checks the whole device and the
partition for an existing filesystem, only creates a filesystem when the
partition is empty, and refuses to partition a device or reformat a partition
that already holds one. The mount task is idempotent, so an existing mount is
left alone. The Proxmox cluster playbook skips cluster creation and joining
when the node already has `/etc/pve/corosync.conf`, and only comments out
Enterprise repositories in files that exist.

## TODO:
- ~Proxmox Cluster~
- ~SSH config~
- ~Replace Enterprise repos with No-Subscription~
- ~Ubuntu OS template~
