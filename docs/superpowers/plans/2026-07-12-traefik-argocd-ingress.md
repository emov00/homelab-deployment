# Traefik and Argo CD Ingress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a reproducible k3d cluster configuration, deploy Traefik through the existing Argo CD infrastructure pattern, and expose Argo CD at `http://argocd.homelab`.

**Architecture:** k3d publishes host ports 80 and 443 through its load-balancer container. An Argo CD ApplicationSet installs the pinned official Traefik Helm chart as a `LoadBalancer` Service, while the Argo CD Helm release creates an HTTP `IngressRoute` to `argocd-server` and enables insecure backend serving.

**Tech Stack:** k3d v1alpha5 configuration, Kubernetes YAML, Argo CD ApplicationSet, Helm, Traefik chart 40.2.0 and Traefik CRDs.

## Global Constraints

- The cluster name is exactly `test-cluster`.
- The cluster has exactly two agents.
- Host ports 80 and 443 are published through k3d's `loadbalancer` node.
- Argo CD is exposed at `http://argocd.homelab` without TLS in this iteration.
- Do not modify `/etc/hosts`; document the mapping for the user to perform manually.
- Follow the existing `homelab/infrastructure/*-appset.yaml` and `config/config.yaml` conventions.

---

### Task 1: Reproducible k3d cluster configuration

**Files:**
- Create: `k3d-config.yaml`
- Modify: `README.md`

**Interfaces:**
- Consumes: k3d's `k3d.io/v1alpha5` `Simple` configuration API.
- Produces: a cluster whose load-balancer accepts host HTTP and HTTPS traffic on ports 80 and 443.

- [ ] **Step 1: Confirm the future configuration is absent**

Run:

```bash
test ! -e k3d-config.yaml
```

Expected: exit code 0.

- [ ] **Step 2: Add the k3d configuration**

Create `k3d-config.yaml` with:

```yaml
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: test-cluster
servers: 1
agents: 2
ports:
  - port: 80:80
    nodeFilters:
      - loadbalancer
  - port: 443:443
    nodeFilters:
      - loadbalancer
```

- [ ] **Step 3: Document cluster creation and manual hostname setup**

Replace `README.md` with:

````markdown
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
````

- [ ] **Step 4: Validate the k3d configuration**

Run:

```bash
k3d config process --config k3d-config.yaml
```

Expected: exit code 0 and processed output containing `name: test-cluster`, two agents, and both port mappings.

- [ ] **Step 5: Commit the cluster configuration**

```bash
git add k3d-config.yaml README.md
git commit -m "feat: add reproducible k3d cluster config"
```

### Task 2: Traefik infrastructure ApplicationSet

**Files:**
- Create: `homelab/infrastructure/traefik-appset.yaml`
- Create: `homelab/infrastructure/traefik/config/config.yaml`
- Create: `homelab/infrastructure/traefik/values.yaml`

**Interfaces:**
- Consumes: the `infrastructure` AppProject, destination cluster name `homelab`, and official `https://traefik.github.io/charts` Helm repository.
- Produces: a `traefik` Argo CD Application and a Traefik `LoadBalancer` Service exposing the `web` and `websecure` entrypoints.

- [ ] **Step 1: Write a structural assertion that initially fails**

Run:

```bash
ruby -ryaml -e 'a=YAML.load_file("homelab/infrastructure/traefik-appset.yaml"); abort unless a.dig("kind")=="ApplicationSet"'
```

Expected: failure because the file does not exist.

- [ ] **Step 2: Pin the Traefik chart**

Create `homelab/infrastructure/traefik/config/config.yaml` with:

```yaml
chartVersion: 40.2.0
```

- [ ] **Step 3: Configure the Traefik service**

Create `homelab/infrastructure/traefik/values.yaml` with:

```yaml
service:
  spec:
    type: LoadBalancer
```

- [ ] **Step 4: Add the Traefik ApplicationSet**

Create `homelab/infrastructure/traefik-appset.yaml` with:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: traefik
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: https://github.com/emov00/homelab-deployment.git
        revision: main
        files:
          - path: homelab/infrastructure/traefik/config/config.yaml
  template:
    metadata:
      name: traefik
    spec:
      project: infrastructure
      sources:
        - repoURL: https://traefik.github.io/charts
          chart: traefik
          targetRevision: "{{.chartVersion}}"
          helm:
            valueFiles:
              - $values/homelab/infrastructure/traefik/values.yaml
        - repoURL: https://github.com/emov00/homelab-deployment.git
          targetRevision: main
          ref: values
      destination:
        name: homelab
        namespace: traefik
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
```

- [ ] **Step 5: Validate YAML structure and render the pinned chart**

Run:

```bash
ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' homelab/infrastructure/traefik-appset.yaml homelab/infrastructure/traefik/config/config.yaml homelab/infrastructure/traefik/values.yaml
helm repo add traefik https://traefik.github.io/charts
helm template traefik traefik/traefik --version 40.2.0 --namespace traefik -f homelab/infrastructure/traefik/values.yaml
```

Expected: all commands exit 0; rendered output contains a `Service` named `traefik` with `type: LoadBalancer` and ports 80 and 443.

- [ ] **Step 6: Commit the Traefik application**

```bash
git add homelab/infrastructure/traefik-appset.yaml homelab/infrastructure/traefik/config/config.yaml homelab/infrastructure/traefik/values.yaml
git commit -m "feat: deploy traefik with argocd"
```

### Task 3: Argo CD IngressRoute and backend mode

**Files:**
- Modify: `homelab/infrastructure/argocd/values.yaml`

**Interfaces:**
- Consumes: Traefik's `web` entrypoint and `traefik.io/v1alpha1` CRDs.
- Produces: an `IngressRoute` in `argocd` that maps `argocd.homelab` to `argocd-server:80` and an Argo CD server that accepts HTTP from Traefik.

- [ ] **Step 1: Write a values assertion that initially fails**

Run:

```bash
ruby -ryaml -e 'v=YAML.load_file("homelab/infrastructure/argocd/values.yaml"); abort unless v.dig("configs","params","server.insecure")==true && v.fetch("extraObjects").any? { |o| o["kind"]=="IngressRoute" }'
```

Expected: non-zero exit because `server.insecure` and `extraObjects` are absent.

- [ ] **Step 2: Configure Argo CD and its route**

Replace `homelab/infrastructure/argocd/values.yaml` with:

```yaml
configs:
  params:
    server.insecure: true
  secret:
    argocdServerAdminPassword: "$2a$10$eJCUOENTy5qjIpYSll8XZeoDp0qy0hIQCfUbXh3OMyqUHzrYpTyDG"

extraObjects:
  - apiVersion: traefik.io/v1alpha1
    kind: IngressRoute
    metadata:
      name: argocd-server
      namespace: argocd
      annotations:
        argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    spec:
      entryPoints:
        - web
      routes:
        - kind: Rule
          match: Host(`argocd.homelab`)
          services:
            - name: argocd-server
              port: 80
```

- [ ] **Step 3: Run focused structural validation**

Run:

```bash
ruby -ryaml -e 'v=YAML.load_file("homelab/infrastructure/argocd/values.yaml"); r=v.fetch("extraObjects").find { |o| o["kind"]=="IngressRoute" }; abort unless v.dig("configs","params","server.insecure")==true && r.dig("metadata","namespace")=="argocd" && r.dig("spec","entryPoints")==["web"] && r.dig("spec","routes",0,"match")=="Host(`argocd.homelab`)" && r.dig("spec","routes",0,"services",0)=={"name"=>"argocd-server", "port"=>80}'
```

Expected: exit code 0.

- [ ] **Step 4: Render the Argo CD chart**

Run:

```bash
helm template argocd argo/argo-cd --version 10.1.1 --namespace argocd -f homelab/infrastructure/argocd/values.yaml
```

Expected: exit code 0 and rendered output includes the `argocd-server` IngressRoute in namespace `argocd`.

- [ ] **Step 5: Run repository-wide YAML and whitespace checks**

Run:

```bash
ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' $(find . -name '*.yaml' -not -path './.git/*')
git diff --check
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit the Argo CD ingress configuration**

```bash
git add homelab/infrastructure/argocd/values.yaml
git commit -m "feat: expose argocd through traefik"
```
