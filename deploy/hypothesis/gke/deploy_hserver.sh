kubectl create configmap nginx-proxy-conf --from-file=proxy.conf
kubectl create -f smtp_config.yaml
kubectl create -f hserver_config.yaml
kubectl create -f hserver.yaml
kubectl create -f hserver_service.yaml
