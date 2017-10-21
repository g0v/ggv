Google Cloud Container Engine(GTK) Environment
===============
Install [Google Cloud SDK](https://cloud.google.com/sdk/gcloud/)
----------------
* Check out the latest instrution from [sdk website](https://cloud.google.com/sdk/docs/)
```
# Install gcloud SDK (ubuntu/debian)
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install google-cloud-sdk
sudo apt-get install google-cloud-sdk-app-engine-java

# Get project authentication from google cloud
gcloud init
```

Install [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
-----------------
* If you don't have gtk cluster, build one.
```
# Install Kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Add GTK Context to Kubectl
gcloud container clusters get-credentials [Cluster Name] --zone asia-east1-a --project [ProjectID]

# Check current context
kubectl config get-contexts

# Switch context if you need it
kubectl config set-context [Context Name]

# Access GTK dashboard
kubectl proxy

# Open browser and navigating to the following location
# http://localhost:8001/ui
```

Install [CloudSQL Proxy](https://cloud.google.com/sql/docs/postgres/connect-external-app#proxy)
-----------------
* If you don't have CloudSQL instance, build one.
* Enable CloudSQL API, [click me](https://console.cloud.google.com/flows/enableapi?apiid=sqladmin&redirect=https://console.cloud.google.com&_ga=2.98831070.-1765009602.1507523494)

```
# Install CloudSQL
sudo wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /usr/local/bin/cloud_sql_proxy
sudo chmod +x /usr/local/bin/cloud_sql_proxy

# Get application default credential
gcloud auth application-default login

# Start CloudSQL Proxy
./cloud_sql_proxy -instances=[Project ID]:[INSTANCE_CONNECTION_NAME]=tcp:5432 &

# Noy you can access CloudSQL through localhost:5432
```

Install hypothsis Backend Service
------------------
* deploy_service.sh deploy elastic and rabbitmq in GTK
* postgresql is a standalone cloudsql
* Create service account for GTK
  1. Go to [Service Accounts](https://console.cloud.google.com/projectselector/iam-admin/serviceaccounts)
  2. Select the project
  3. Click "Create Service Account", enter a "account name", check "Furnish a new private key" and select "JSON"
  4. For Role, select Cloud SQL > Cloud SQL Client
  5. Download the Private Key and keep it safe 
```
# Install elastic and rabbitmq in K8s
./deploy_service.sh

# Connect to Database
psql -h127.0.0.1 -Upostgres -W

# Initialize Database
CREATE DATABASE h;
CREATE DATABASE htest;
\q  #quit

# Setup User for DB if you need it
CREATE USER hserver;
alter user hserver with encrypted password 'hserver';
grant all privileges on database h to hserver;
grant all privileges on database htest to hserver;

# Import Private Key to GTK
kubectl create secret generic cloudsql-instance-credentials \
                       --from-file=credentials.json=[PROXY_KEY_FILE_PATH]

# Create the secret needed for database access (user/pass)
kubectl create secret generic cloudsql-db-credentials \
                       --from-literal=username=postgres --from-literal=password=[PASSWORD]
```

Install [h server](https://github.com/hypothesis/h)
---------------------
* check [config.py](https://github.com/hypothesis/h/blob/master/h/config.py) for config detail
* Create a [Build Trigger](https://console.cloud.google.com/gcr/triggers) for h
  1. You need to get Source Repository Administrator role for this project, [check this](https://console.cloud.google.com/iam-admin/iam/project)
  2. Select GitHub as source
  3. set the image name as ggv/hserver
```
# Create a [Build Trigger](https://console.cloud.google.com/gcr/triggers) for h

# Generate deploy file
./build_h.sh [Project ID]:[INSTANCE_CONNECTION_NAME]

# edit config file if you need
vim hserver.yaml
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
