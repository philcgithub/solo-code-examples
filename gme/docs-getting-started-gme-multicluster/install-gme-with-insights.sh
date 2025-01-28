# Check GLOO_MESH_LICENSE_KEY was set
if [[ -z "$GLOO_MESH_LICENSE_KEY" ]]; then
    echo "GLOO_MESH_LICENSE_KEY not set, please set with a valid license key and try again"
    exit 1
else
    echo $VAR
fi


export MGMT_CLUSTER=k3d-mgmt
export REMOTE_CLUSTER1=k3d-cluster1
export REMOTE_CLUSTER2=k3d-cluster2
kubectl config get-contexts
export MGMT_CONTEXT=mgmt
export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2
meshctl install --profiles mgmt-server \
--kubecontext $MGMT_CONTEXT \
--set common.cluster=$MGMT_CLUSTER \
--set glooInsightsEngine.enabled=true \
--set licensing.glooMeshLicenseKey=$GLOO_MESH_LICENSE_KEY
kubectl get pods -n gloo-mesh --context $MGMT_CONTEXT
export TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
export TELEMETRY_GATEWAY_PORT=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
export TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo $TELEMETRY_GATEWAY_ADDRESS

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '*'
      namespaces:
        - name: '*'
---
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh-config
---
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh-config
spec:
  options:
    serviceIsolation:
      enabled: false
    federation:
      enabled: false
      serviceSelector:
      - {}
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
EOF

meshctl cluster register $REMOTE_CLUSTER1 \
--kubecontext $MGMT_CONTEXT \
--remote-context $REMOTE_CONTEXT1 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS \
--gloo-mesh-agent-chart-values -<<EOF
glooAnalyzer:
  enabled: true
EOF

meshctl cluster register $REMOTE_CLUSTER2 \
--kubecontext $MGMT_CONTEXT \
--remote-context $REMOTE_CONTEXT2 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS \
--gloo-mesh-agent-chart-values -<<EOF
glooAnalyzer:
  enabled: true
EOF

sleep 10
meshctl check --kubecontext $REMOTE_CONTEXT1
meshctl check --kubecontext $REMOTE_CONTEXT2
meshctl check --kubecontext $MGMT_CONTEXT

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: istiod-control-plane
  namespace: gloo-mesh
spec:
  installations:
  - clusters:
    - defaultRevision: true
      name: $REMOTE_CLUSTER1
    - defaultRevision: true
      name: $REMOTE_CLUSTER2
    istioOperatorSpec:
      components:
        pilot:
          k8s:
            env:
            - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
              value: "false"
            - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
              value: "true"
      meshConfig:
        accessLogFile: /dev/stdout
        defaultConfig:
          holdApplicationUntilProxyStarts: true
          proxyMetadata:
            ISTIO_META_DNS_CAPTURE: "true"
        outboundTrafficPolicy:
          mode: ALLOW_ANY
        rootNamespace: istio-system
      namespace: istio-system
      profile: minimal
    revision: auto
EOF

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: istio-eastwestgateway
  namespace: gloo-mesh
spec:
  installations:
  - clusters:
    - activeGateway: true
      name: $REMOTE_CLUSTER1
    - activeGateway: true
      name: $REMOTE_CLUSTER2
    gatewayRevision: auto
    istioOperatorSpec:
      components:
        ingressGateways:
        - enabled: true
          k8s:
            service:
              ports:
                - port: 15021
                  targetPort: 15021
                  name: status-port
                - port: 15443
                  targetPort: 15443
                  name: tls
              selector:
                istio: eastwestgateway
              type: LoadBalancer
          label:
            istio: eastwestgateway
            app: istio-eastwestgateway
          name: istio-eastwestgateway
          namespace: gloo-mesh-gateways
      namespace: istio-system
      profile: empty
EOF

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: istio-ingressgateway
  namespace: gloo-mesh
spec:
  installations:
  - clusters:
    - activeGateway: true
      name: $REMOTE_CLUSTER1
    - activeGateway: true
      name: $REMOTE_CLUSTER2
    gatewayRevision: auto
    istioOperatorSpec:
      components:
        ingressGateways:
        - enabled: true
          k8s:
            service:
              ports:
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
            #serviceAnnotations:
            #  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: ssl
            #  service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
            #  service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
            #  service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
            #  service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:<cert>"
            #  service.beta.kubernetes.io/aws-load-balancer-type: external
          label:
            istio: ingressgateway
            app: istio-ingressgateway
          name: istio-ingressgateway
          namespace: gloo-mesh-gateways
      namespace: istio-system
      profile: empty
EOF

kubectl get ns --context $REMOTE_CONTEXT1
kubectl get ns --context $REMOTE_CONTEXT2

sleep 15
kubectl get mesh -n gloo-mesh --context $REMOTE_CONTEXT1
kubectl get mesh -n gloo-mesh --context $REMOTE_CONTEXT2