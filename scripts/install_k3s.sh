#!/bin/bash
set -e

# Install K3s if not found
if ! command -v k3s &> /dev/null; then
    echo "Installing K3s..."
    curl -sfL https://get.k3s.io | sh -
else
    echo "K3s already installed."
fi

# Wait for K3s to be ready (check for k3s.yaml)
echo "Waiting for K3s kubeconfig..."
MAX_RETRIES=30
count=0
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
    if [ $count -ge $MAX_RETRIES ]; then
        echo "Timed out waiting for k3s.yaml"
        exit 1
    fi
    sleep 2
    count=$((count+1))
done

# Ensure the config is readable
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

echo "K3s is ready."
