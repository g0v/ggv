#!/bin/bash

if [ $# -eq 0  ]; then
    echo "Usage: \"./build_h.sh [DB_CONNECTION_NAME(ProjectID:Region:InstanceName)]\"";
    exit
fi

db_address=$1
image_url=$(gcloud container builds list | grep hserver | awk '{print $5}')

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
        - image: $image_url
          imagePullPolicy: Always
          name: hserver
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"10m\"
          envFrom:
            - configMapRef:
                name: hserver-config
          ports:
            - containerPort: 5000
              name: hserver-tcp
        - image: b.gcr.io/cloudsql-docker/gce-proxy:1.11
          name: cloudsql-proxy
          command: [\"/cloud_sql_proxy\", \"--dir=/cloudsql\",
                    \"-instances=$db_address=tcp:5432\",
                    \"-credential_file=/secrets/cloudsql/credentials.json\"]
          volumeMounts:
            - name: cloudsql-instance-credentials
              mountPath: /secrets/cloudsql
              readOnly: true
            - name: ssl-certs
              mountPath: /etc/ssl/certs
            - name: cloudsql
              mountPath: /cloudsql
        - image: namshi/smtp
          name: smtp
          resources:
            requests:
              memory: "64Mi"
              cpu: "10m"
          ports:
            - containerPort: 25
              name: smtp-tcp
          envFrom:
            - configMapRef:
                name: smtp-config
      volumes:
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
        - name: cloudsql
          emptyDir:
" >> hserver.yaml

secret_key=`python -c 'import base64; import os; print(base64.urlsafe_b64encode(os.urandom(48)))'`
ip=127.0.0.1

echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: hserver-config
  namespace: default
data:
  BROKER_URL: amqp://guest:guest@rabbit:5672//
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
  # CLIENT_OAUTH_ID
  # CLIENT_ID
  # CLIENT_SECRET
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
