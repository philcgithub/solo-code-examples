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

sleep 15

meshctl check

kubectl get pods -n istio-system

# Solo distrubution of Istio patch version and tag, in the format 1.x.x-solo
export ISTIO_IMAGE=1.23.4-solo
# Solo distrubution of Istio repo
export REPO=us-docker.pkg.dev/gloo-mesh/istio-207627c16668
# Solo distrubution of Istio Helm repo
export HELM_REPO=us-docker.pkg.dev/gloo-mesh/istio-helm-207627c16668

helm upgrade --install istio-base oci://${HELM_REPO}/base \
--namespace istio-system \
--create-namespace \
--version ${ISTIO_IMAGE} \
-f - <<EOF
defaultRevision: ""
profile: ambient
EOF

helm upgrade --install istiod oci://${HELM_REPO}/istiod \
--namespace istio-system \
--version ${ISTIO_IMAGE} \
-f - <<EOF
global:
  hub: ${REPO}
  proxy:
    clusterDomain: cluster.local
  tag: ${ISTIO_IMAGE}
istio_cni:
  namespace: istio-system
  enabled: true
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
env:
  PILOT_ENABLE_IP_AUTOALLOCATE: "true"
  PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
  PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
profile: ambient
EOF

helm upgrade --install istio-cni oci://${HELM_REPO}/cni \
--namespace istio-system \
--version ${ISTIO_IMAGE} \
-f - <<EOF
ambient:
  dnsCapture: true
excludeNamespaces:
  - istio-system
  - kube-system
global:
  hub: ${REPO}
  tag: ${ISTIO_IMAGE}
profile: ambient
EOF

helm upgrade --install ztunnel oci://${HELM_REPO}/ztunnel \
--namespace istio-system \
--version ${ISTIO_IMAGE} \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
hub: ${REPO}
istioNamespace: istio-system
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: ${ISTIO_IMAGE}
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway oci://${HELM_REPO}/gateway \
--namespace istio-ingress \
--create-namespace \
--version ${ISTIO_IMAGE} \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
service:
  type: LoadBalancer
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
EOF

sleep 5

kubectl get pods -A | grep istio

kubectl get svc -n istio-ingress
