# Traefik and Argo CD Ingress Design

## Goal

Run Traefik as the ingress controller in the k3d homelab cluster and make Argo CD available over HTTP at `http://argocd.homelab`.

## Cluster configuration

Add a top-level `k3d-config.yaml` using the k3d configuration-file API. It will create a cluster named `test-cluster` with one server and two agents. The k3d load-balancer container will publish host ports 80 and 443 to the same ports in the cluster, making Traefik reachable from the host.

The hostname remains a local DNS concern. For a single workstation, `/etc/hosts` can map `argocd.homelab` to `127.0.0.1`; a homelab DNS server can provide the equivalent record.

## Traefik deployment

Follow the existing infrastructure ApplicationSet pattern:

- `homelab/infrastructure/traefik-appset.yaml` defines the generated Argo CD Application.
- `homelab/infrastructure/traefik/config/config.yaml` pins the Traefik Helm chart version.
- `homelab/infrastructure/traefik/values.yaml` contains the chart configuration.
- The application deploys to a dedicated `traefik` namespace in the `homelab` cluster and uses the existing `infrastructure` AppProject.
- Traefik exposes its `web` and `websecure` entrypoints through a `LoadBalancer` Service. k3s ServiceLB and k3d's published ports carry that traffic to the host.

The ApplicationSet will use the official Traefik Helm repository and the repository's values file, matching the multi-source approach already used for Argo CD.

## Argo CD route

Add a Traefik `IngressRoute` manifest in the Argo CD infrastructure configuration. It will:

- live in the `argocd` namespace;
- listen on Traefik's `web` entrypoint;
- match ``Host(`argocd.homelab`)``;
- forward traffic to the `argocd-server` Service on port 80.

The first iteration is intentionally HTTP-only. Port 443 is published so TLS can be added later without recreating the cluster.

## Argo CD configuration

Update `homelab/infrastructure/argocd/values.yaml` to set `configs.params.server.insecure: true`. Argo CD will then serve HTTP behind Traefik instead of redirecting clients to its own HTTPS endpoint, avoiding redirect loops and certificate mismatch issues.

The IngressRoute will be supplied through the Argo CD Helm release's `extraObjects` support. This keeps the route with the application it exposes and ensures it targets the correct namespace. It will include Argo CD's `SkipDryRunOnMissingResource` sync option so the initial bootstrap can tolerate the Traefik CRD being installed in the separate infrastructure application.

## Bootstrap and validation

The README will document cluster creation from `k3d-config.yaml`, hostname resolution, and the expected URL. Validation will include:

- parsing all changed YAML files;
- rendering or linting the Helm releases if the required CLI and chart access are available;
- checking that the k3d port mappings, Traefik service type, hostname rule, namespace, backend service, backend port, and Argo CD insecure mode match this design.

Traefik must be synced before or alongside Argo CD's updated release during the first rollout because Kubernetes cannot create an `IngressRoute` until Traefik's CRD exists. Argo CD retrying the sync after Traefik is healthy is sufficient if both are initially discovered together.
