kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install -n gloo-system gloo gloo/gloo \
--create-namespace \
--version 1.19.0-beta2 \
-f -<<EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
kubeGateway:
  enabled: true
EOF

sleep 5

kubectl get pods -n gloo-system | grep gloo

kubectl get gatewayclass gloo-gateway

kubectl apply -n gloo-system -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

sleep 5
kubectl get gateway http -n gloo-system