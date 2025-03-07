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

## TODO:
- ~Proxmox Cluster~
- ~SSH config~
- ~Replace Enterprise repos with No-Subscription~
- ~Ubuntu OS template~
