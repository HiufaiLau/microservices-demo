#!/bin/bash
set -euo pipefail

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting K3s installation..."

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget git

# Install K3s
echo "Installing K3s version ${k3s_version}..."

# Get IPs
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Install K3s with TLS SAN for Elastic IP
# Note: We add both the current public IP and a wildcard to handle Elastic IP assignment
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${k3s_version}" sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --node-external-ip="$PUBLIC_IP" \
  --node-ip="$PRIVATE_IP" \
  --tls-san="$PUBLIC_IP"

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
timeout 300 bash -c 'until kubectl get nodes; do sleep 5; done'

# Set proper permissions for kubeconfig
chmod 644 /etc/rancher/k3s/k3s.yaml

echo "K3s installation complete!"
echo "Node info:"
kubectl get nodes -o wide

# Create a status file for verification
cat > /var/lib/cloud/instance/k3s-ready <<EOF
K3s installation completed at: $(date)
K3s version: ${k3s_version}
Node name: $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
EOF

echo "User data script completed successfully!"
