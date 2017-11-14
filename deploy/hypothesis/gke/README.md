Google Cloud Container Engine(GKE) Environment
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

# Add GKE Context to Kubectl
gcloud container clusters get-credentials [Cluster Name] --zone asia-east1-a --project [ProjectID]

# Check current context
kubectl config get-contexts

# Switch context if you need it
kubectl config set-context [Context Name]

# Access GKE dashboard
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
* deploy_service.sh deploy elastic and rabbitmq in GKE
* postgresql is a standalone cloudsql
* Create service account for GKE
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

# Import Private Key to GKE
kubectl create secret generic cloudsql-instance-credentials \
                       --from-file=credentials.json=[PROXY_KEY_FILE_PATH]

# Create the secret needed for database access (user/pass)
kubectl create secret generic cloudsql-db-credentials \
                       --from-literal=username=postgres --from-literal=password=[PASSWORD]
```

Install [h server](https://github.com/hypothesis/h)
---------------------
* check [config.py](https://github.com/hypothesis/h/blob/master/h/config.py) for config detail
* Enable [Container Builder API](https://console.cloud.google.com/flows/enableapi?apiid=cloudbuild.googleapis.com)
```
# Build h server Image using container builder
gcloud container builds submit --config hserver_builder.yaml --no-source

# Or you can push your image into container registry
docker tag [IMAGE] [HOSTNAME]/[PROJECT-ID]/[IMAGE][:TAG]
gcloud docker -- push [HOSTNAME]/[PROJECT-ID]/[IMAGE][:TAG]

# Generate deploy file, the DB_CONNECTION_NAME includes Project ID, Region, Instance Name
./build_h.sh [DB_CONNECTION_NAME]

# edit config file, especially the passowrd of postgres and mail sender
vim hserver.yaml
vim hserver_config.yaml

# edit smtp config, default using gmail as backend, check out the document from [namshi/smtp](https://github.com/namshi/docker-smtp) for config detail
vim smtp_config.yaml

# Deploy h
./deploy_hserver.sh

# Initial Database
kubectl exec -c hserver -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis --app-url=http://ggv.tw init
```

Access h server
--------------------
* Activate service port in [Instance groups](https://console.cloud.google.com/compute/instanceGroups/list)
  1. Edit the GKE Group
  2. Add port http/30080
  3. No health check
* Create [Firwall Rule]
  1. click "Create a firewall rule"
  2. Name(allow-hserver-healthcheck), Targets(Specified target tags), Target tags(GKT Cluster subnetwork), Source Filter(IP ranges), Source IP ranges(0.0.0.0/0), Protocols and ports(tcp:30080)
* Create a [Load Balancer](https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list) for GKE cluster
  1. click "Create Load Balancer"
  2. select "HTTP Load Balancer"
  3. Backend Service -> Create a backend service -> name(hserver-http), protocol(http), Named port(http), Instance Group(the gtk group)
  4. Health Check -> Create a new health check -> port: 30080, timeout: 5s, check interval: 5s, unhealthy threshold: 2 attempts
  4. Frontend Configuration -> Create a new IPv4/IPv6 for this service
  5. click "Create"
```

# Open Browser and access http://ip/

# Create user for testing (USERNAME:test  PASSWORD:test)
kubectl exec -c hserver -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis --app-url=http://ggv.tw user add --username test --password test --email test@test.com

# Create user for admin (USERNAME:admin_user PASSWORD:admin)
kubectl exec -c hserver -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis --app-url=http://ggv.tw user add --username admin_user --password admin --email admin@test.com
kubectl exec -c hserver -it $(kubectl get pods | grep hserver | cut -d' ' -f1) -- hypothesis user admin admin_user
```

Setup Oauth for h server
--------------------
* Apple a oauth client for app.html
  1. open http://ip/ and login as admin_user
  2. open http://ip/admin/oauthclients and add a new oauth client
     * Name: app
     * Authority: ggv.tw
     * Grant type: authorization_code
     * Trusted: checked
     * Redirect URL: http://ip
  3. click save and copy the Client ID
* Edit Server config
```
# Edit config
vim hserver_config.yaml

# Add oauth-related env var
CLIENT_URL: http://ip/client
CLIENT_OAUTH_ID: [Client ID]
CLIENT_RPC_ALLOWED_ORIGINS: http://ip

# Apple new config
kubectl replace -f hserver_config.yaml

# Delete current hserver pods and generate new one
```

SSL Certificate
--------------------
```
brew install certbot
sudo certbot certonly --manual -d [DOMAIN NAME]

# Create Bucket for LoadBalancer for verify
# Load balancering > Edit the load balancer Frontend configuration > Backend configuration > Create backend bucket
# Load balancering > Host and path rules > Add the following rules
#	[Domain]   /.well-known/acme-challenge/*     [Your Bucket]
#       [Domain]   /*                                [Your Backend Server]

# Import Certification
# Load balancering > Edit the load balancer Frontend configuration > Add protocol > https > import cert > done
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
  "apiUrl": "https://[DOMAIN]/api/",
  "authDomain": "[DOMAIN]",
  "bouncerUrl": "https://[DOMAIN]/",
  "serviceUrl": "https://[DOMAIN]/",
  "websocketUrl": "wss://[DOMAIN]/ws",
# If you wanna build plugin in production mode, you should comment out tools/settings.js:33 throw error(...)

# Build
make

# Install Extension
# Open Chrome > Menu > More Tools > Extensions > check "Developer Mode" > click "load unpacked extension..."
# select the folder browser-extension/build

# If you running the server without SSL, chrome would drop unsecure connection when you browse secure website.
```

Install [Hypothesis Client](https://github.com/hypothesis/client)
-----------------------
* the client is build and upload to google cloud storage
```
# Get Source Code
git clone https://github.com/hypothesis/client.git
cd client

# Configurateion
vim gulpfile.js
# Change Line 273 to your domain
272:  if (process.env.NODE_ENV === 'production') {
273:    defaultAssetRoot = `https://cdn.hypothes.is/hypothesis/${version}/`;
274:  } else {

# Env
export NODE_ENV=production
export SIDEBAR_APP_URL=https://kuansim.org/app.html

# Build
make clean
make

# Upload to Google Cloud Storage: hclient
gsutil cp -r -a public-read build/* gs://hclient/client/build/
gsutil cp -r -a public-read build/boot.js  gs://hclient/client/
gsutil web set -m boot.js -e client/build/boot.js gs://hclient

# Fix CORS problem
gsutil cors set storage_cors.json gs://hclient

# Setup load balancer to bucket
# Hosts: Domain
# Path: /client/*, /client 
# Backend: hclient
```

Install [Hypothesis Via Server](https://github.com/hypothesis/via)
-----------------------
```
# Get source code
git clone https://github.com/hypothesis/via
cd via

# Configuration
vim config.yaml
# Add your domain under no_rewrite_prefixes

# Build Via image
build_via.sh [Your Project ID]

# Edit viaserver.yaml
vim viaserver.yaml
# Set H_EMBED_URL to your client url https://[Your Domain]/client/boot.js
# Set CORS_ALLOW_ORIGINS to your h server domain 

# Deploy
kubectl create -f viaserver.yaml
kubectl create -f viaserver_service.yaml
```
