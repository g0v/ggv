#!/bin/bash

if [ $# -eq 0  ]; then
    echo "Usage: \"./build_h.sh [Project ID]:[INSTANCE_CONNECTION_NAME]\"";
    exit
fi

db_address=$1

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hserver
spec:
  replicas: 1
  template:
    metadata:
      labels:
        service: hserver
    spec:
      containers:
        - image: ggv/hserver
          imagePullPolicy: Always
          name: hserver
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"100m\"
          envFrom:
            - configMapRef:
                name: hserver-config
          ports:
            - containerPort: 5000
              name: hserver-tcp
        - image: b.gcr.io/cloudsql-docker/gce-proxy:1.05
          name: cloudsql-proxy
          command: [\"/cloud_sql_proxy\", \"--dir=/cloudsql\",
                    \"-instances=$1=tcp:5432\",
                    \"-credential_file=/secrets/cloudsql/credentials.json\"]
          volumeMounts:
            - name: cloudsql-oauth-credentials
              mountPath: /secrets/cloudsql
              readOnly: true
            - name: ssl-certs
              mountPath: /etc/ssl/certs
            - name: cloudsql
              mountPath: /cloudsql
" >> hserver.yaml

client_id=$(uuidgen)
client_secret=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
secret_key=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
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
" >> hserver_config.yaml
