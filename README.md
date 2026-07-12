# homelab-deployment

## Create the cluster

The configuration publishes ports 80 and 443 through the k3d load balancer for Traefik:

```bash
k3d cluster create --config k3d-config.yaml
```

If the browser is running on the k3d host, add this hostname mapping manually to `/etc/hosts`:

```text
127.0.0.1 argocd.homelab
```

For the first bootstrap, sync the applications in this order:

1. Sync `bootstrap-infrastructure` so it generates the infrastructure applications.
2. Sync `traefik`, then wait for it to become Healthy so its CRDs are available.
3. Sync or re-sync `argocd`.

`SkipDryRunOnMissingResource` only skips Argo CD's dry-run check; the API server still rejects the `IngressRoute` until Traefik's CRD exists. If `argocd` was synced before Traefik became Healthy, retry the `argocd` sync after Traefik is ready.

Then open <http://argocd.homelab>.

> **Warning:** This URL is HTTP-only. Credentials and session traffic are not encrypted in transit.

## References

- [Argo CD application deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/#app-deletion)
- [Argo CD Helm chart](https://artifacthub.io/packages/helm/argo/argo-cd)
