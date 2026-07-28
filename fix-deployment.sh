#!/bin/bash
# Script to fix and deploy Sock Shop application

set -e

INSTANCE_ID="i-0dd60330cc4a99b2c"
REGION="eu-central-1"

echo "🔧 Fixing Sock Shop Deployment..."
echo "=================================="

# Function to run command via SSM
run_ssm_command() {
  local cmd="$1"
  local desc="$2"

  echo ""
  echo "📝 $desc"

  CMD_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$cmd\"]" \
    --query "Command.CommandId" \
    --output text \
    --region "$REGION")

  echo "   Command ID: $CMD_ID"
  echo "   Waiting for command to complete..."

  # Wait for command
  sleep 10

  # Get output
  aws ssm get-command-invocation \
    --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null || echo "   (Command still running or no output)"
}

# Check K3s status
run_ssm_command "systemctl status k3s | head -10" "Checking K3s status"

# Check if namespace exists
run_ssm_command "kubectl get namespace sock-shop 2>&1 || echo 'Namespace does not exist'" "Checking sock-shop namespace"

# Deploy Sock Shop
echo ""
echo "🚀 Deploying Sock Shop application..."
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["kubectl apply -f https://raw.githubusercontent.com/microservices-demo/microservices-demo/master/deploy/kubernetes/complete-demo.yaml"]' \
  --query "Command.CommandId" \
  --output text \
  --region "$REGION")

echo "   Deployment command sent: $CMD_ID"
echo "   Waiting 15 seconds..."
sleep 15

aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query "StandardOutputContent" \
  --output text 2>/dev/null || echo "   Still deploying..."

# Check pods
echo ""
echo "📊 Checking pod status..."
sleep 10
run_ssm_command "kubectl get pods -n sock-shop" "Pod status"

# Check front-end service
echo ""
echo "🌐 Checking front-end service..."
run_ssm_command "kubectl get svc -n sock-shop front-end" "Front-end service"

echo ""
echo "=================================="
echo "✅ Deployment commands sent!"
echo ""
echo "⏰ Wait 5-10 minutes for all pods to start"
echo "🔍 Check status with: ./check-deployment-status.sh"
echo "🌐 Then visit: http://sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com/"
