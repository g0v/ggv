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

Install hyposis Backend Service
------------------
```
./deploy_service.sh
```
