export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

kubectl -n httpbin get pods --context $REMOTE_CONTEXT1

kubectl create ns helloworld --context $REMOTE_CONTEXT1
kubectl label ns helloworld istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1

kubectl create ns helloworld --context $REMOTE_CONTEXT2
kubectl label ns helloworld istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT2
kubectl -n helloworld apply --context $REMOTE_CONTEXT1 -l 'service=helloworld' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml
kubectl -n helloworld apply --context $REMOTE_CONTEXT1 -l 'app=helloworld,version in (v1, v2)' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml
kubectl -n helloworld apply --context $REMOTE_CONTEXT2 -l 'service=helloworld' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml
kubectl -n helloworld apply --context $REMOTE_CONTEXT2 -l 'app=helloworld,version in (v3, v4)' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml

sleep 5
kubectl -n helloworld get pods --context $REMOTE_CONTEXT1
kubectl -n helloworld get pods --context $REMOTE_CONTEXT2