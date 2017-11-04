kubectl create configmap pybossa-nginx-proxy-conf --from-file=proxy.conf
kubectl create -f pybossa-background.yaml
kubectl create -f pybossa.yaml
kubectl create -f pybossa_service.yaml
