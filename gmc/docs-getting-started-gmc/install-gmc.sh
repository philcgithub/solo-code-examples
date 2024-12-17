# Check GLOO_MESH_CORE_LICENSE_KEY was set
if [[ -z "$GLOO_MESH_CORE_LICENSE_KEY" ]]; then
    echo "GLOO_MESH_CORE_LICENSE_KEY not set, please set with a valid license key and try again"
    exit 1
else
    echo $VAR
fi

# Assume meshctl is already installed
#curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v2.6.6 sh -
#export PATH=$HOME/.gloo-mesh/bin:$PATH

export CLUSTER_NAME=cluster1

meshctl install --profiles gloo-core-single-cluster \
--set common.cluster=$CLUSTER_NAME \
--set licensing.glooMeshCoreLicenseKey=$GLOO_MESH_CORE_LICENSE_KEY

meshctl check

kubectl get pods -n istio-system

export REPO=us-docker.pkg.dev/gloo-mesh/istio-4d37697f9711

kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: istiod-control-plane
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
        - name: $CLUSTER_NAME
      istioOperatorSpec:
        hub: $REPO
        tag: 1.24.1-solo
        profile: ambient
        components:
          cni:
            namespace: istio-system
            enabled: true
        values:
          ztunnel:
            env:
              L7_ENABLED: true
---
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: istio-ingressgateway
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
        - name: $CLUSTER_NAME
      istioOperatorSpec:
        hub: $REPO
        tag: 1.24.1-solo
        profile: empty
        components:
          ingressGateways:
          - enabled: true
            k8s:
              service:
                ports:
                  # Port for health checks on path /healthz/ready.
                  # For AWS ELBs, must be listed as the first port
                  - name: status-port
                    port: 15021
                    targetPort: 15021
                  - name: http2
                    port: 80
                    targetPort: 8080
                  - name: https
                    port: 443
                    targetPort: 8443
                  - name: tls
                    port: 15443
                    targetPort: 15443
                selector:
                  istio: ingressgateway
                type: LoadBalancer
            label:
              app: istio-ingressgateway
              istio: ingressgateway
            name: istio-ingressgateway
            namespace: gloo-mesh-gateways
EOF

sleep 5

kubectl get pods -A | grep istio
kubectl get svc -n gloo-mesh-gateways