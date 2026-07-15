echo "### Creating k3d cluster ###"
k3d cluster create --config k3d-config.yaml --wait
echo "### Cluster created ###"


echo "### Installing Argo CD ###"
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 10.1.2 \
  --wait 
echo "### Argo CD installation complete ###"

echo "### Applying bootstrap-project-project ###"
kubectl apply -f homelab/projects/bootstrap-project-project.yaml --wait

echo "### Applying home-cluster ###"
kubectl apply -f homelab/cluster/homelab-cluster.yaml --wait

ehco "### Applying bootstrap ###"
kubectl apply -f bootstrap.yaml --wait

echo "### Setting namespace to argocd ###"
kubectl config set-context --current --namespace=argocd

echo "### Syncing bootstrap ###"
argocd login --core
argocd app sync bootstrap
argocd app wait bootstrap --sync --health --timeout 300

echo "### Syncing bootstrap-cluster ###"
argocd app sync bootstrap-cluster
argocd app wait bootstrap-cluster --sync --health --timeout 300

echo "### Syncing bootstrap-project ###"
argocd app sync bootstrap-project
argocd app wait bootstrap-project --sync --health --timeout 300

echo "### Syncing bootstrap-infrastructure ###"
argocd app sync bootstrap-infrastructure
argocd app wait bootstrap-infrastructure --sync --health --timeout 300

echo "### Syncing traefik ###"
# traefik is weirdly entering the degraded state before becoming healthy
# this exits out of `argocd app wait` then argocd start syncing anyway
# use kubectl to check health instead

argocd app sync traefik

echo "### Waiting for traefik to be healthy ###"
kubectl wait application/traefik \
--namespace argocd \
--for=jsonpath='{.status.health.status}'=Healthy \
--timeout=300s

echo "### Syncing argocd ###"
argocd app sync argocd
argocd app wait argocd --sync --health --timeout 300

echo "Waiting for Argo CD ingress..."

until curl --fail --silent --show-error \
  --location \
  --max-time 5 \
  "http://argocd.homelab.me" \
  >/dev/null 2>&1; do
  echo "Argo CD is not available yet; retrying in 10 seconds..."
  sleep 10
done

echo "Argo CD is available at http://argocd.homelab.me."

