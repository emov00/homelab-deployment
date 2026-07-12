# homelab-deployment

## Create the cluster

The configuration publishes ports 80 and 443 through the k3d load balancer for Traefik:

```bash
k3d cluster create --config k3d-config.yaml
```

Add this hostname mapping manually to `/etc/hosts`:

```text
127.0.0.1 argocd.homelab
```

After bootstrapping and syncing the infrastructure applications, open <http://argocd.homelab>.

## References

- [Argo CD application deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/#app-deletion)
- [Argo CD Helm chart](https://artifacthub.io/packages/helm/argo/argo-cd)
