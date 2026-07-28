#!/bin/bash
set -euo pipefail

echo "Fixing K3s TLS certificate to include Elastic IP..."
echo ""

# Get values from Terraform
INSTANCE_ID=$(terraform output -raw server_instance_id)
ELASTIC_IP=$(terraform output -raw server_public_ip)

echo "Instance ID: $INSTANCE_ID"
echo "Elastic IP: $ELASTIC_IP"
echo ""

# Create a script to run on the instance
REMOTE_SCRIPT=$(cat <<'SCRIPT'
#!/bin/bash
set -euo pipefail

ELASTIC_IP="ELASTIC_IP_PLACEHOLDER"

echo "Stopping K3s..."
systemctl stop k3s

echo "Backing up K3s data..."
cp -r /var/lib/rancher/k3s/server/tls /var/lib/rancher/k3s/server/tls.backup

echo "Removing old certificates..."
rm -rf /var/lib/rancher/k3s/server/tls

echo "Restarting K3s with new TLS SAN..."
# Add the Elastic IP to the K3s configuration
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - $ELASTIC_IP
EOF

systemctl start k3s

echo "Waiting for K3s to be ready..."
sleep 10
timeout 120 bash -c 'until kubectl get nodes 2>/dev/null; do sleep 2; done'

echo "K3s certificate updated successfully!"
kubectl get nodes
SCRIPT
)

# Replace placeholder with actual IP
REMOTE_SCRIPT="${REMOTE_SCRIPT//ELASTIC_IP_PLACEHOLDER/$ELASTIC_IP}"

echo "Sending command to instance via SSM..."
CMD_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters commands="$REMOTE_SCRIPT" \
    --comment "Fix K3s TLS certificate" \
    --query "Command.CommandId" \
    --output text)

echo "Command ID: $CMD_ID"
echo "Waiting for command to complete..."

aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID"

echo ""
echo "Getting command output..."
aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" \
    --output text

echo ""
echo "Checking for errors..."
ERROR_OUTPUT=$(aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardErrorContent" \
    --output text)

if [ -n "$ERROR_OUTPUT" ] && [ "$ERROR_OUTPUT" != "None" ]; then
    echo "Errors:"
    echo "$ERROR_OUTPUT"
fi

echo ""
echo "Done! K3s certificate should now include the Elastic IP."
