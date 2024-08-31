# Rolling Proxmox VMs using Terraform

## Prerequisites
- Terraform v1.9.2
- telmate/proxmox v3.0.1-rc1
- Ceph configured on all Proxmox nodes
- An OS template set up on one of the nodes

## How to:
1. Fill out `terraform.tfvars` (See example below)
2. Update values in `variables.tf` where necessary
3. Plan and apply Terraform as usual

## Example `terraform.tfvars`
```
# Proxmox API token details
# Create one here: Datacenter -> Permissions -> API Token -> Add
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "000ab000-0c0d-0a0f-b000-00c00da00bc0"

# Hashed password for root user
root_password            = "$6$MjNhK15PjsN9$dQeAe3EmxBM5jcY9egkA5qynBLYYZiPLaPjEfvP9U0iDiFb2MxM6gZd/yrQ088MqUF/xWVVyq77X23zaRvmem/"

# SSH private key for root user
root_ssh_key             = <<-EOF
-----BEGIN OPENSSH PRIVATE KEY-----
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-----END OPENSSH PRIVATE KEY-----
EOF
```

## TODO:
- ~Provision master and worker nodes~
- ~Cloud-Init~
- ~Auto k8s cluster with cloud-init~
- Ceph and k8s version vars
- Support for multiple master nodes
