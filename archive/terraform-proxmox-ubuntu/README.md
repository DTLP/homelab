# <img align="left" width="40px" src="https://www.iconsdb.com/icons/preview/orange/warning-xxl.png" /> No longer maintained

# Rolling Proxmox VMs using Terraform

I used to use this to roll out my Ubuntu k8s nodes in Proxmox. This is archived
as I have moved on to using Talos for k8s nodes.

## Prerequisites
- Terraform v1.9.2
- telmate/proxmox v3.0.1-rc1
- An OS template set up on one of the nodes

## How to:
1. Fill out `terraform.tfvars`
2. Update values in `variables.tf` where necessary
3. Plan and apply Terraform as usual
