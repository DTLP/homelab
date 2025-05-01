# Proxmox API token details
# Create one here: Datacenter -> Permissions -> API Token -> Add
# (Make sure Privilege Separation box is unchecked)
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "a123a12a-a12a-1234-a123-123a12ab12ab"

# Hashed password. Examples can be found in /etc/shadow
root_password = "$$6$rounds=4096$9lpDxZAiTz/pE6Xs9IXt7P1uu4hU0HHdR.upjNKq5T0W1$Bey6chWRYCjd7QPoz659LWG2UBOELYhjjL2969fnwBAmSgA.UUzz."
# SSH key you will use to access the nodes
root_ssh_key = <<-EOF
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZWYyLTEyM2QwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAw
-----END OPENSSH PRIVATE KEY-----
EOF
