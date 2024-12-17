kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FaultInjectionPolicy
metadata:
  name: faultinjection-basic-delay
  namespace: bookinfo
spec:
  applyToRoutes:
    - route:
        labels:
          route: ratings
  config:
    delay:
      fixedDelay: 10s
---
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: ratings-rt
  namespace: bookinfo
spec:
  hosts:
  - ratings
  http:
  - forwardTo:
      destinations:
      - ref:
          name: ratings
          namespace: bookinfo
    labels:
      route: ratings
  workloadSelectors:
  - {}
EOF