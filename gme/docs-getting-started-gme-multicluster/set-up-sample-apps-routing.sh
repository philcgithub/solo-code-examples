kubectl apply --context $MGMT_CONTEXT -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
EOF
kubectl rollout restart deployment istiod-$REVISION -n istio-system --context $REMOTE_CONTEXT1
kubectl rollout restart deployment istiod-$REVISION -n istio-system --context $REMOTE_CONTEXT2
kubectl rollout restart deployment details-v1 productpage-v1 ratings-v1 reviews-v1 reviews-v2 -n bookinfo --context $REMOTE_CONTEXT1
kubectl rollout restart deployment ratings-v1 reviews-v3 -n bookinfo --context $REMOTE_CONTEXT2
kubectl rollout restart deployment httpbin -n httpbin --context $REMOTE_CONTEXT1
kubectl rollout restart deployment helloworld-v1 helloworld-v2 -n helloworld --context $REMOTE_CONTEXT1
kubectl rollout restart deployment helloworld-v3 helloworld-v4 -n helloworld --context $REMOTE_CONTEXT2

kubectl apply --context $MGMT_CONTEXT -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: reviews-vd
  namespace: bookinfo
spec:
  hosts:
  # Arbitrary, internal-only hostname assigned to the endpoint
  - reviews.mesh.internal.com
  ports:
  - number: 9080
    protocol: HTTP
  services:
    - labels:
        app: reviews
EOF

kubectl apply --context $MGMT_CONTEXT -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: bookinfo-east-west
  namespace: bookinfo
spec:
  hosts:
    - 'reviews.bookinfo.svc.cluster.local'
  workloadSelectors:
    - selector:
        labels:
          app: productpage
  http:
    - name: reviews
      matchers:
      - uri:
          prefix: /reviews
      forwardTo:
        destinations:
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 9080
      labels:
        route: reviews
EOF

# kubectl --context ${REMOTE_CONTEXT1} -n bookinfo port-forward deployment/productpage-v1 9080:9080