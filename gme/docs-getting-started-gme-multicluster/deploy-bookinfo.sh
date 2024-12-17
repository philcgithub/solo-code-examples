# bookinfo
export MGMT_CONTEXT=mgmt
export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION

kubectl create ns bookinfo --context $MGMT_CONTEXT

kubectl create ns bookinfo --context $REMOTE_CONTEXT1
kubectl label ns bookinfo istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1

kubectl create ns bookinfo --context $REMOTE_CONTEXT2
kubectl label ns bookinfo istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT2

# deploy bookinfo application components for all versions less than v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)' --context $REMOTE_CONTEXT1
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
# deploy all bookinfo service accounts --context $REMOTE_CONTEXT1
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account' --context $REMOTE_CONTEXT1

# deploy reviews and ratings services
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service in (reviews)' --context $REMOTE_CONTEXT2
# deploy reviews-v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (reviews),version in (v3)' --context $REMOTE_CONTEXT2
# deploy ratings
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings)' --context $REMOTE_CONTEXT2
# deploy reviews and ratings service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.22.5/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (reviews, ratings)' --context $REMOTE_CONTEXT2

sleep 5
kubectl get pods -n bookinfo --context $REMOTE_CONTEXT1
kubectl get pods -n bookinfo --context $REMOTE_CONTEXT2