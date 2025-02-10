helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm install istio-base istio/base -n istio-system --create-namespace --wait

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

helm install istiod istio/istiod --namespace istio-system --set profile=ambient --wait
helm install istio-cni istio/cni -n istio-system --set profile=ambient --set global.platform=k3d --wait
helm install ztunnel istio/ztunnel -n istio-system --wait

helm show values istio/istiod

helm ls -n istio-system

kubectl get pods -n istio-system