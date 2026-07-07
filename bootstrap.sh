kubectl apply -f homelab/projects/bootstrap-project-project.yaml 

kubectl apply -f homelab/cluster/homelab-cluster.yaml 

kubectl apply -f bootstrap.yaml

sync bootstrap

sync bootstrap-cluster

sync bootstrap-projects

sync bootstrap-infrastructure

sync bootstrap-apps

