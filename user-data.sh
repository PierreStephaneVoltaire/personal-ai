#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -ex

export PATH=$PATH:/usr/local/bin

echo "Public IP: $PUBLIC_IP"

dnf update -y
dnf install -y git wget tar gzip jq nodejs docker python3.11

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user || true

# Wait for and mount persistent EBS volume for K3s data
echo "Waiting for EBS volume to attach..."
DEVICE="/dev/nvme1n1"  # /dev/sdf appears as nvme1n1 on Nitro instances
MAX_WAIT=60
count=0
while [ ! -b "$DEVICE" ] && [ $count -lt $MAX_WAIT ]; do
  echo "Waiting for device $DEVICE... ($count/$MAX_WAIT)"
  sleep 2
  count=$((count + 1))
done

if [ ! -b "$DEVICE" ]; then
  echo "ERROR: Device $DEVICE not found after waiting"
  exit 1
fi

echo "Device $DEVICE found, checking filesystem..."

# Check if device has a filesystem
if ! blkid "$DEVICE"; then
  echo "No filesystem found, formatting $DEVICE as ext4..."
  mkfs.ext4 "$DEVICE"
else
  echo "Existing filesystem found on $DEVICE"
fi

# Create mount point and mount
mkdir -p /var/lib/rancher
if mount | grep -q /var/lib/rancher; then
  echo "/var/lib/rancher already mounted"
else
  echo "Mounting $DEVICE to /var/lib/rancher..."
  mount "$DEVICE" /var/lib/rancher
fi

# Add to fstab if not already present
if ! grep -q "/var/lib/rancher" /etc/fstab; then
  DEVICE_UUID=$(blkid -s UUID -o value "$DEVICE")
  echo "UUID=$DEVICE_UUID /var/lib/rancher ext4 defaults,nofail 0 2" >> /etc/fstab
fi

echo "K3s data volume mounted successfully"

if ! command -v helm &> /dev/null; then
  curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.14.0-linux-arm64.tar.gz
  tar -zxvf /tmp/helm.tar.gz -C /tmp
  mv /tmp/linux-arm64/helm /usr/local/bin/helm
  chmod +x /usr/local/bin/helm
  rm -rf /tmp/linux-arm64 /tmp/helm.tar.gz
fi

if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

if systemctl is-active --quiet k3s; then
  echo "k3s already running, stopping for reconfiguration..."
  systemctl stop k3s
fi

rm -rf /etc/rancher/k3s/k3s.yaml
rm -rf /var/lib/rancher/k3s/server/node-token

export INSTALL_K3S_EXEC="server \
  --datastore-endpoint='${db_endpoint}' \
  --token='${k3s_token}' \
  --write-kubeconfig-mode 644"

curl -sfL https://get.k3s.io | sh -

until [ -f /etc/rancher/k3s/k3s.yaml ]; do
  echo "Waiting for k3s.yaml..."
  sleep 5
done

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Waiting for k3s API server to be ready..."
until kubectl get nodes &>/dev/null; do
  echo "Still waiting for API server..."
  sleep 5
done

CURRENT_NODE=$(cat /etc/hostname)
echo "Current node: $CURRENT_NODE"

echo "Cleaning up old/stale nodes..."
kubectl get nodes -o json | jq -r '.items[] | select(.metadata.name != "'$CURRENT_NODE'") | .metadata.name' | while read OLD_NODE; do
  echo "Deleting old node: $OLD_NODE"
  kubectl delete node "$OLD_NODE" --ignore-not-found=true || true
done

echo "Cleaning up orphaned PersistentVolumes..."
kubectl get pv -o json | jq -r '.items[] | select(.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0] != "'$CURRENT_NODE'") | .metadata.name' | while read PV_NAME; do
  echo "Checking PV: $PV_NAME"

  PVC_NAME=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || echo "")
  PVC_NAMESPACE=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null || echo "")

  if [ -n "$PVC_NAME" ] && [ -n "$PVC_NAMESPACE" ]; then
    echo "PV $PV_NAME is bound to PVC $PVC_NAMESPACE/$PVC_NAME with wrong node affinity"

    PODS_USING_PVC=$(kubectl get pods -n "$PVC_NAMESPACE" -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == "'$PVC_NAME'") | .metadata.name' || echo "")

    if [ -z "$PODS_USING_PVC" ]; then
      echo "No pods using PVC $PVC_NAMESPACE/$PVC_NAME, safe to delete and recreate"
      kubectl delete pvc "$PVC_NAME" -n "$PVC_NAMESPACE" --ignore-not-found=true || true
      echo "Deleted orphaned PVC: $PVC_NAMESPACE/$PVC_NAME"
    else
      echo "WARNING: PVC $PVC_NAMESPACE/$PVC_NAME is in use by pods: $PODS_USING_PVC"
      echo "Manual intervention required for: $PVC_NAMESPACE/$PVC_NAME"
    fi
  else
    echo "Deleting unbound PV: $PV_NAME"
    kubectl delete pv "$PV_NAME" --ignore-not-found=true || true
  fi
done

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ || true
helm repo add jetstack https://charts.jetstack.io || true
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable || true
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls} || true

kubectl create namespace cattle-system || true

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait

helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.${PUBLIC_IP}.nip.io \
  --set replicas=1 \
  --set bootstrapPassword=admin \
  --wait

aws ssm put-parameter \
  --name "/${project_name}/${environment}/k3s/kubeconfig" \
  --value "$(sed 's|server: https://.*:6443|server: https://${PUBLIC_IP}:6443|g' /etc/rancher/k3s/k3s.yaml)" \
  --type SecureString \
  --region "${region}" \
  --overwrite

echo "user-data complete at $(date)"