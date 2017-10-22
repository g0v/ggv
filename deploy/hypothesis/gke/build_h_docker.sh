eval $(minikube docker-env)
docker build -t ggv/hserver github.com/hypothesis/h
