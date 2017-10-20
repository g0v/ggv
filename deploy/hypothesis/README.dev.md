Environment
===============
Install [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
-----------------
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

Install [Docker CE](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)
-------------------
```
# Update Apt
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Install Key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Repo
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Install
sudo apt-get update
sudo apt-get install docker-ce

# Setup Docker permission for current developer, and you need relogin
sudo adduser ${whoami} docker
```

Install [Minikube](https://github.com/kubernetes/minikube)
------------------
```
# Install
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

# Start minikube
minikube start --container-runtime=docker

# Open K8s dashboard
minikube dashboard
```

Install hypothsis Backend Service
------------------
```
# Install service in K8s
./deploy_service.sh

# Initialize Database
kubectl exec -it $(kubectl get pods | grep postgres | cut -d' ' -f1) -- su -c "psql -c 'CREATE DATABASE h;';psql -c 'CREATE DATABASE htest;'" postgres

# Setup User for DB
kubectl exec -it $(kubectl get pods | grep postgres | cut -d' ' -f1) -- su -c " \
psql -c 'CREATE USER hserver;'; \
psql -c \"alter user hserver with encrypted password 'hserver';\"; \
psql -c \"grant all privileges on database h to hserver;\"; \
psql -c \"grant all privileges on database htest to hserver;\"; \
" postgres
```

Install [h server](https://github.com/hypothesis/h)
---------------------
```
# Build image from github
./build_h_docker.sh

# Generate config file
./build_h_env.sh

# edit config file if you need
# check [config.py](https://github.com/hypothesis/h/blob/master/h/config.py) for config detail
vim hserver_config.yaml

# Deploy h
./deploy_hserver.sh

# Initial Database
kubectl exec -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis --app-url=http://$(minikube ip) init
```

Access h server
--------------------
```
# Get minikube service ip
minikube ip

# Open Browser and access http://ip:30080/
```
