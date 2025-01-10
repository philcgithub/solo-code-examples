# Check GLOO_GATEWAY_LICENSE_KEY was set
if [[ -z "$GLOO_GATEWAY_LICENSE_KEY" ]]; then
    echo "GLOO_GATEWAY_LICENSE_KEY not set, please set with a valid license key and try again"
    exit 1
else
    echo $VAR
fi

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update

 helm install -n gloo-system gloo-gateway glooe/gloo-ee \
--create-namespace \
--version 1.18.2 \
--set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
-f -<<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
  gloo:
    disableLeaderElection: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF

sleep 5

kubectl get pods -n gloo-system

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