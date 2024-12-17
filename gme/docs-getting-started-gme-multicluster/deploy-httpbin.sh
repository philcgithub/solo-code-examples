export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION
kubectl create ns httpbin --context $REMOTE_CONTEXT1
kubectl label ns httpbin istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml --context $REMOTE_CONTEXT1

sleep 5
kubectl -n httpbin get pods --context $REMOTE_CONTEXT1