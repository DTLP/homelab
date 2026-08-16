# ArgoCD notes
1. Apply using `kustomize build . | k -n argocd apply -f -`.
   On the first apply there's a bug:
   `InvalidSpecError  Application referencing project default which does not exist`
   Comment out the `project:` line, apply, remove the comment and apply again.

2. Get the service address and admin password
```
k -n argocd get service argocd-server
    NAME            TYPE          CLUSTER-IP      EXTERNAL-IP    PORT(S)
    argocd-server   LoadBalancer  10.109.235.142  192.168.0.56   8083:31460/TCP,80:31356/TCP,443:31692/TCP

https://argocd.dtlp.cc

k -n argocd get secrets argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

username: admin
password: <use the command above>
```

3. One ArgoCD Application per namespace lives in that namespace's directory as
   `argocd-app.yaml` and is referenced by that namespace's kustomization. The
   controller watches all namespaces (`application.namespaces: "*"`), and each
   app targets the `main` project.
