#!/bin/bash

echo 'This script assumes that you have a working kubernetes cluster, the kubectl context is set to it and helm v3 installed (all latest versions)' 

# Add helm repositories
helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Setup Grommunio Jitsi
helm install \
	gromox-meet jitsi/jitsi-meet \
	-f video/video-values.yml

# Setup cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.10.0 \
  --set installCRDs=true \
  --create-namespace

helm repo add jetstack https://charts.jetstack.io
sleep 30s

kubectl apply -f db-config.yaml
kubectl apply -f ssl-config.yaml
kubectl apply -f redis-config.yaml
kubectl apply -f admin-config.yaml
kubectl apply -f admin-plugins-config.yaml
kubectl apply -f admin-links-config.yaml
kubectl apply -f redis.yaml
kubectl apply -f db.yaml
sleep 60s
kubectl apply -f init-db.yaml
sleep 90s
kubectl apply -f gromox.yaml
sleep 60s
