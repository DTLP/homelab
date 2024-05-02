# ArgoCD notes
1. Apply using `kustomize build . | k -n sys-argocd apply -f -`  
On the first apply there's a bug:  
`InvalidSpecError  Application referencing project default which does not exist`  
Comment out the `project: default` line, apply, remove comment and apply again

2. Get node address, service port and admin password
```
k -n sys-argocd describe pods -l app.kubernetes.io/name=argocd-server | grep worker
    Node:             kv-worker-0/10.0.0.20

k -n sys-argocd get service argocd-server
    NAME            TYPE       CLUSTER-IP       PORT(S)
    argocd-server   NodePort   10.106.227.95    80:31781/TCP,443:31815/TCP

https://10.0.0.20:31781

k -n sys-argocd get secrets argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

username: admin
password: <use the command above>
```
