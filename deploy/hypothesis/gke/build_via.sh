#!/bin/bash

if [ $# -eq 0  ]; then
    echo "Usage: \"./build_via.sh [PROJECT ID]\"";
    exit
fi

project_id=$1
image_url="asia.gcr.io/${project_id}/viaserver"

docker build -t hypothesis/via -t ${image_url} via/.
gcloud docker -- push ${image_url}:latest

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: viaserver
spec:
  replicas: 1
  template:
    metadata:
      labels:
        service: viaserver
    spec:
      containers:
        - image: ${image_url}
          imagePullPolicy: Always
          name: viaserver
          env:
            - name: H_EMBED_URL
              value: https://kuansim.org/client/boot.js
            - name: CORS_ALLOW_ORIGINS
              value: https://kuansim.org http://kuansim.org
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
          ports:
            - containerPort: 9080
              name: viaserver-tcp
" >> viaserver.yaml

client_id=$(uuidgen)
client_secret=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
secret_key=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
client_oauth_id=$(uuidgen)
ip=127.0.0.1

echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: hserver-config
  namespace: default
data:
  BROKER_URL: amqp://guest:guest@rabbit:5672//
  CLIENT_ID: $client_id
  CLIENT_SECRET: $client_secret
  DATABASE_URL: postgres://postgres:postgres@localhost:5432/h
  ELASTICSEARCH_HOST: http://elastic:9200
  SECRET_KEY: $secret_key
  AUTHORITY: ggv.tw
  WEBSOCKET_URL: ws://$ip:30080/ws
  APP_URL: http://$ip:30080/
  MAIL_DEFAULT_SENDER: [USERNAME]@gmail.com
  MAIL_HOST: 127.0.0.1
  MAIL_PORT: "25"
  # CLIENT_URL
  CLIENT_OAUTH_ID: $client_oauth_id
  # CLIENT_RPC_ALLOWED_ORIGINS: http://localhost:5000
" >> hserver_config.yaml

echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: smtp-config
  namespace: default
data:
  GMAIL_USER: [USERNAME]@gmail.com
  GMAIL_PASSWORD: [PASSWORD]
" >> smtp_config.yaml
