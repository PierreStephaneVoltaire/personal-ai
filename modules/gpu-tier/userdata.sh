#!/bin/bash
set -e
dnf install -y kernel-devel kernel-headers
dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
dnf install -y cuda-toolkit nvidia-driver
VOLUME_ID="${volume_id}"
MODELS_PATH="${models_path}"
TIER_NAME="${tier_name}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

mkdir -p $MODELS_PATH

DEVICE=$(lsblk -o NAME,SERIAL | grep $(echo $VOLUME_ID | tr -d '-') | awk '{print "/dev/"$1}' || true)
if [ -z "$DEVICE" ]; then
  aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/xvdf --region $REGION
  sleep 10
  DEVICE="/dev/xvdf"
fi

if ! blkid $DEVICE; then
  mkfs.ext4 $DEVICE
fi

mount $DEVICE $MODELS_PATH
echo "$DEVICE $MODELS_PATH ext4 defaults,nofail 0 2" >> /etc/fstab

curl -fsSL https://ollama.com/install.sh | sh

mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << EOF
[Service]
Environment="OLLAMA_MODELS=$MODELS_PATH"
Environment="OLLAMA_HOST=0.0.0.0"
EOF

systemctl daemon-reload
systemctl enable ollama
systemctl start ollama
