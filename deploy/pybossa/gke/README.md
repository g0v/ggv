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

Install pybossa Backend Service
------------------
* postgresql is a standalone cloudsql
* Create service account for GKE
  1. Go to [Service Accounts](https://console.cloud.google.com/projectselector/iam-admin/serviceaccounts)
  2. Select the project
  3. Click "Create Service Account", enter a "account name", check "Furnish a new private key" and select "JSON"
  4. For Role, select Cloud SQL > Cloud SQL Client
  5. Download the Private Key and keep it safe 
```
# Install redis cluster
./deploy_redis.sh

# Connect to Database
psql -h127.0.0.1 -Upostgres -W

# Initialize Database
CREATE DATABASE pybossa;
\q  #quit

# Import Private Key to GKE
kubectl create secret generic cloudsql-instance-credentials \
                       --from-file=credentials.json=[PROXY_KEY_FILE_PATH]

# Create the secret needed for database access (user/pass)
kubectl create secret generic cloudsql-db-credentials \
                       --from-literal=username=postgres --from-literal=password=[PASSWORD]
```

Install [pybossa server](https://github.com/Scifabric/pybossa)
---------------------
* Enable [Container Builder API](https://console.cloud.google.com/flows/enableapi?apiid=cloudbuild.googleapis.com)
* [Docker Image](https://github.com/jvstein/docker-pybossa)
```
# Generate deploy file, the DB_CONNECTION_NAME includes Project ID, Region, Instance Name
./build_pybossa.sh [DB_CONNECTION_NAME]

# edit config file, especially the passowrd of postgres and mail sender
vim pybossa.yaml
vim pybossa_config.yaml
vim pybossa-init.yaml
vim pybossa-background.yaml

# initial config file
kubectl create -f pybossa_config.yaml

# initial database
kubectl create -f pybossa-init.yaml

# Deploy h
./deploy_pybossa.sh

```

Access pybossa server
--------------------
* Activate service port in [Instance groups](https://console.cloud.google.com/compute/instanceGroups/list)
  1. Edit the GKE Group
  2. Add port http/30000
  3. No health check
* Create [Firwall Rule]
  1. click "Create a firewall rule"
  2. Name(allow-pybossa-healthcheck), Targets(Specified target tags), Target tags(GKT Cluster subnetwork), Source Filter(IP ranges), Source IP ranges(0.0.0.0/0), Protocols and ports(tcp:30090)
* Create a [Load Balancer](https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list) for GKE cluster
  1. click "Create Load Balancer"
  2. select "HTTP Load Balancer"
  3. Backend Service -> Create a backend service -> name(hserver-http), protocol(http), Named port(http), Instance Group(the gtk group)
  4. Health Check -> Create a new health check -> port: 30090, timeout: 5s, check interval: 5s, unhealthy threshold: 2 attempts
  4. Frontend Configuration -> Create a new IPv4/IPv6 for this service
  5. click "Create"
```

# Open Browser and access http://ip/
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

