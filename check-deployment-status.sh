#!/bin/bash
# Script to check Sock Shop deployment status

echo "🔍 Checking Sock Shop Deployment Status..."
echo "=========================================="
echo ""

# Check target health
echo "📊 Load Balancer Target Health:"
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:414772274298:targetgroup/ssstg-20260422065437631200000004/053bfb4a7553b263 \
  --region eu-central-1 \
  --query "TargetHealthDescriptions[0].TargetHealth" \
  --output table

echo ""
echo "🌐 Testing Application URLs:"
echo "----------------------------"

echo -n "ALB URL: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com/ --max-time 5)
if [ "$HTTP_CODE" == "200" ]; then
  echo "✅ Working! (HTTP $HTTP_CODE)"
else
  echo "⏳ Not ready yet (HTTP $HTTP_CODE)"
fi

echo -n "Direct URL: "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://3.65.228.51:30080/ --max-time 5)
if [ "$HTTP_CODE" == "200" ]; then
  echo "✅ Working! (HTTP $HTTP_CODE)"
else
  echo "⏳ Not ready yet (HTTP $HTTP_CODE)"
fi

echo ""
echo "📋 Getting Pod Status via SSM..."
CMD_ID=$(aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["kubectl get pods -n sock-shop"]' \
  --query "Command.CommandId" \
  --output text \
  --region eu-central-1)

sleep 5

aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id i-0dd60330cc4a99b2c \
  --region eu-central-1 \
  --query "StandardOutputContent" \
  --output text 2>/dev/null || echo "⏳ K3s still initializing..."

echo ""
echo "=========================================="
echo "📝 Summary:"
echo "  ALB URL: http://sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com/"
echo "  Direct:  http://3.65.228.51:30080/"
echo ""
echo "Run this script again in a few minutes to check progress!"
