#!/bin/bash

if [ $# -eq 0  ]; then
    echo "Usage: \"./build_pybossa.sh [DB_CONNECTION_NAME(ProjectID:Region:InstanceName)]\"";
    exit
fi

db_address=$1

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: pybossa
spec:
  replicas: 1
  template:
    metadata:
      labels:
        service: pybossa
    spec:
      containers:
        - image: nginx
          name: pybossa-web
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"10m\"
          lifecycle:
            preStop:
              exec:
                command: [\"/usr/sbin/nginx\",\"-s\",\"quit\"]
          volumeMounts:
            - name: \"pybossa-nginx-proxy-conf\"
              mountPath: \"/etc/nginx/conf.d\"
          ports:
            - containerPort: 5000
              name: pybossa-tcp
        - image: jvstein/pybossa
          imagePullPolicy: Always
          name: pybossa
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"10m\"
          envFrom:
            - configMapRef:
                name: pybossa-config
          command: [\"python\", \"app_context_rqworker.py\", \"scheduled_jobs\", \"super\", \"high\", \"medium\", \"low\", \"email\", \"maintenance\"]
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
      volumes:
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
        - name: cloudsql
          emptyDir:
        - name: \"pybossa-nginx-proxy-conf\"
          configMap:
            name: \"pybossa-nginx-proxy-conf\"
            items:
              - key: \"proxy.conf\"
                path: \"proxy.conf\"
" >> pybossa.yaml

echo "apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: pybossa-bg
spec:
  replicas: 1
  template:
    metadata:
      labels:
        service: pybossa-bg
    spec:
      containers:
        - image: jvstein/pybossa
          imagePullPolicy: Always
          name: pybossa-bg
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"10m\"
          envFrom:
            - configMapRef:
                name: pybossa-config
          args:
            - python
            - app_context_rqworker.py
            - scheduled_jobs
            - super
            - high
            - medium
            - low
            - email
            - maintenance
        - image: b.gcr.io/cloudsql-docker/gce-proxy:1.11
          name: cloudsql-proxy
          command: [\"/cloud_sql_proxy\", \"--dir=/cloudsql\",
                    \"-instances=$db_address=tcp:5432\",
                    \"-credential_file=/secrets/cloudsql/credentials.json\"]
          resources:
            requests:
              memory: \"64Mi\"
              cpu: \"10m\"
          volumeMounts:
            - name: cloudsql-instance-credentials
              mountPath: /secrets/cloudsql
              readOnly: true
            - name: ssl-certs
              mountPath: /etc/ssl/certs
            - name: cloudsql
              mountPath: /cloudsql
      volumes:
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
        - name: cloudsql
          emptyDir:
" >> pybossa-background.yaml

echo "apiVersion: batch/v1
kind: Job
metadata:
  name: init-pyb-db
spec:
  template:
    metadata:
      name: init-pyb-db
    spec:
      containers:
      - name: init-database
        image: jvstein/pybossa
        args:
          - python
          - cli.py
          - db_create
        envFrom:
          - configMapRef:
              name: pybossa-config
        resources:
          requests:
            memory: \"64Mi\"
            cpu: \"10m\"
      - image: b.gcr.io/cloudsql-docker/gce-proxy:1.11
        name: cloudsql-proxy
        command: [\"/cloud_sql_proxy\", \"--dir=/cloudsql\",
                  \"-instances=ggv-notetool:asia-east1:hypothsis=tcp:5432\",
                  \"-credential_file=/secrets/cloudsql/credentials.json\"]
        resources:
          requests:
            memory: \"64Mi\"
            cpu: \"10m\"
        volumeMounts:
          - name: cloudsql-instance-credentials
            mountPath: /secrets/cloudsql
            readOnly: true
          - name: ssl-certs
            mountPath: /etc/ssl/certs
          - name: cloudsql
            mountPath: /cloudsql
      restartPolicy: Never
      volumes:
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
        - name: cloudsql
          emptyDir:
  backoffLimit: 4
" >> pybossa-init.yaml 

echo "apiVersion: v1
kind: ConfigMap
metadata:
  name: pybossa-config
  namespace: default
data:
  POSTGRES_URL: postgresql://postgres:postgres@localhost:5432/pybossa
  REDIS_SENTINEL: redis-sentinel
  REDIS_MASTER: redis-master
" >> pybossa_config.yaml

