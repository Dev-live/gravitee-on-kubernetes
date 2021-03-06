#!/bin/sh
##
# Script to deploy a Kubernetes cluster with pods and services for Gravitee gateway, management API and UI.
# This is script uses local variables set in your terminal. Before running this, make sure to fill out following variables:
# =========================================================
# MONGO_ROOT_USER
# MONGO_ROOT_PASSWORD
# MONGO_DEFAULT_REGION_ZONE
# MONGO_CLUSTER_NAME
# ELASTIC_CLUSTER_NAME
# GRAVITEE_DEFAULT_REGION_ZONE
# GRAVITEE_CLUSTER_NAME
# GRAVITEE_MONGO_DBNAME
# GRAVITEE_MONGO_USERNAME
# GRAVITEE_MONGO_PASSWORD
# =========================================================
# Example:
# $ export MONGO_ROOT_USER=main_admin
# $ export MONGO_ROOT_PASSWORD=abc123
# $ export MONGO_DEFAULT_REGION_ZONE=us-central1-a
# $ export MONGO_CLUSTER_NAME=gke-mongodb-cluster
# $ export ELASTIC_CLUSTER_NAME=gke-elastic-cluster
# $ export GRAVITEE_DEFAULT_REGION_ZONE=us-west1-a
# $ export GRAVITEE_CLUSTER_NAME=apim-gravitee-cluster
# $ export GRAVITEE_MONGO_DBNAME=gravitee
# $ export GRAVITEE_MONGO_USERNAME=gravitee
# $ export GRAVITEE_MONGO_PASSWORD=gravitee123
##

# Update secrets and config files with values from user input (terminal variables)
# MongoDB
sed -i -e "s|GRAVITEE_MONGO_USERNAME|${GRAVITEE_MONGO_USERNAME:-default gravitee}|g" \ 
-e "s|GRAVITEE_MONGO_PASSWORD|${GRAVITEE_MONGO_PASSWORD:-default gravitee123}|g" \ 
-e "s|GRAVITEE_MONGO_DBNAME|${GRAVITEE_MONGO_DBNAME:-default gravitee}|g" \ 
-e "s|GRAVITEE_MONGO_HOST|${MONGO_HOST}|g" \ 
-e "s|GRAVITEE_MONGO_PORT|${MONGO_PORT:-default 27017}|g" \ 
./Gravitee/GKE/Gateway/mongo-secret.yaml > /tmp/mongo-secret.yaml

# Elasticsearch
sed -i -e "s|GRAVITEE_ELASTIC_HOST|${ELASTIC_HOST}|g" \ 
-e "s|GRAVITEE_ELASTIC_PORT|${ELASTIC_PORT:-default 9200}|g" \ 
./Gravitee/GKE/Gateway/elastic-search-secret.yaml > /tmp/elastic-search-secret.yaml

# Update Gateway replicas quantity (default is 2)
sed -i -e "s|GRAVITEE_GATEWAY_REPLICAS_QTY|${GRAVITEE_GATEWAY_REPLICAS_QTY:-default 2}|g" ./Gravitee/GKE/Gateway/deployment-gateway.yaml > deployment-gateway.yaml

# Set default region/zone
gcloud config set compute/zone $GRAVITEE_DEFAULT_REGION_ZONE

# Create new GKE Kubernetes cluster
gcloud container clusters create "${GRAVITEE_CLUSTER_NAME}" --image-type=UBUNTU --machine-type=n1-standard-1

# Switch context to the newly created cluster
kubectl config use-context $GRAVITEE_CLUSTER_NAME

# Deploy...
kubectl create -f /tmp/mongo-secret.yaml
kubectl create -f /tmp/elastic-search-secret.yaml
kubectl create -f /tmp/deployment-gateway.yaml
kubectl create -f ./Gravitee/GKE/Gateway/expose-gravitee-gateway.yaml

# Export IP address of exposed Gravitee Gateway service
export GRAVITEE_GATEWAY_HOST=$(kubectl get svc/service-gravitee-gateway -o yaml | grep ip | cut -d':' -f 2 | cut -d' ' -f 2)
export GRAVITEE_GATEWAY_PORT=$(kubectl get svc/service-gravitee-gateway -o yaml | grep port | cut -d':' -f 2 | cut -d' ' -f 2)

# Check
kubectl get all
echo

sleep 30 # Waiting service to be expose (GKE Load Balancer might take sometime to do it)
echo "Gateway is exposed at http://${GRAVITEE_GATEWAY_HOST}:${GRAVITEE_GATEWAY_PORT}"

rm /tmp/mongo-secret.yaml
rm /tmp/elastic-search-secret.yaml
rm /tmp/deployment-gateway.yaml
