Ubuntu Environment
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

Install [Minikube](https://github.com/kubernetes/minikube) with [KVM driver](https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#kvm-driver)
------------------
```
# Install KVM driver
sudo apt install libvirt-bin qemu-kvm
sudo usermod -a -G libvirtd $(whoami)
newgrp libvirtd #(NOTE: For Ubuntu 17.04 change the group to `libvirt`)
sudo curl -L https://github.com/dhiltgen/docker-machine-kvm/releases/download/v0.10.0/docker-machine-driver-kvm-ubuntu16.04 -o /usr/local/bin/docker-machine-driver-kvm
sudo chmod +x /usr/local/bin/docker-machine-driver-kvm

# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

# Start minikube
minikube start --vm-driver=kvm

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

# Setup User for DB if you need it
kubectl exec -it $(kubectl get pods | grep postgres | cut -d' ' -f1) -- su -c " \
psql -c 'CREATE USER hserver;'; \
psql -c \"alter user hserver with encrypted password 'hserver';\"; \
psql -c \"grant all privileges on database h to hserver;\"; \
psql -c \"grant all privileges on database htest to hserver;\"; \
" postgres
```

Install [h server](https://github.com/hypothesis/h)
---------------------
* check [config.py](https://github.com/hypothesis/h/blob/master/h/config.py) for config detail
```
# Build image from github
./build_h_docker.sh

# Generate config file
./build_h_env.sh

# edit config file if you need
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

# Create user for testing (USERNAME:test  PASSWORD:test)
kubectl exec -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis --app-url=http://$(minikube ip) user add --username test --password test --email test@test.com
```

Test h server using [Browser Extension](https://github.com/hypothesis/browser-extension)
---------------------
* Get service ip from previous step
```
# Get source code
git clone https://github.com/hypothesis/browser-extension
cd browser-extension

# Install package
npm install

# Edit setting
vim settings/chrome-dev.json

# fix the following key
  "apiUrl": "http://[service ip]:30080/api/",
  "authDomain": "localhost",
  "bouncerUrl": "http://[service ip]:30800/",
  "serviceUrl": "http://[service ip]:30080/",
  "websocketUrl": "ws://[service ip]:30080/ws",
# If you wanna build plugin in production mode, you should comment out tools/settings.js:33 throw error(...)

# Build
make

# Install Extension
# Open Chrome > Menu > More Tools > Extensions > check "Developer Mode" > click "load unpacked extension..."
# select the folder browser-extension/build

# If you running the server without SSL, chrome would drop unsecure connection when you browse secure website.
```
