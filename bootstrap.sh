k3d cluster create --config k3d-config.yaml

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 10.1.2

kubectl port-forward service/argocd-server -n argocd 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

kubectl apply -f homelab/projects/bootstrap-project-project.yaml 

kubectl apply -f homelab/cluster/homelab-cluster.yaml 

kubectl apply -f bootstrap.yaml

sync bootstrap

sync bootstrap-cluster

sync bootstrap-projects

sync bootstrap-infrastructure

sync traefik

sync argocd

sync bootstrap-apps

