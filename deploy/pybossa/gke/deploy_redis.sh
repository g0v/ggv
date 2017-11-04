#!/bin/bash

kubectl create -f redis-master.yaml
kubectl -f create redis-master-service.yaml
kubectl create -f redis-sentinel-service.yaml
kubectl create -f redis-controller.yaml
kubectl create -f redis-sentinel-controller.yaml
kubectl scale rc redis --replicas=3
kubectl scale rc redis-sentinel --replicas=3
