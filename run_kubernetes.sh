#!/usr/bin/env bash

# This tags and uploads an image to Docker Hub

# Step 1:
# This is your Docker ID/path
# dockerpath=<>
dockerpath=index.docker.io/cy235/cy235-prediction:v1

# Step 2
# Run the Docker Hub container with kubernetes
kubectl run cy235-prediction --port=80 --image=$dockerpath

# Step 3:
# List kubernetes pods
kubectl get pods

# Step 4:
# Forward the container port to a host
kubectl port-forward $(kubectl get pods -o=name | grep cy235-prediction | sed "s/^.\{4\}//") 8000:80
