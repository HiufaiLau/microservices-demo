#!/bin/bash
set -euo pipefail

echo "Collecting AWS resource identifiers for Terraform import..."
echo ""

# VPC and networking
echo "=== VPC and Networking ==="
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sockshop-staging-vpc" --query 'Vpcs[0].VpcId' --output text)
echo "VPC ID: $VPC_ID"

# Get subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-vpc-public-*" --query 'Subnets[*].SubnetId' --output text)
echo "Subnet IDs: $SUBNET_IDS"

# Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
echo "Internet Gateway ID: $IGW_ID"

# Route Tables
RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-vpc-public" --query 'RouteTables[*].RouteTableId' --output text)
echo "Route Table IDs: $RT_IDS"

echo ""
echo "=== Security Groups ==="
K3S_SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-k3s-server" --query 'SecurityGroups[0].GroupId' --output text)
echo "K3s Security Group ID: $K3S_SG_ID"

ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-alb" --query 'SecurityGroups[0].GroupId' --output text)
echo "ALB Security Group ID: $ALB_SG_ID"

echo ""
echo "=== IAM Resources ==="
IAM_ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'sockshop-staging-k3s-server')].RoleName" --output text | head -1)
echo "IAM Role Name: $IAM_ROLE_NAME"

IAM_PROFILE_NAME=$(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, 'sockshop-staging-k3s-server')].InstanceProfileName" --output text | head -1)
echo "IAM Instance Profile Name: $IAM_PROFILE_NAME"

echo ""
echo "=== EC2 Instance ==="
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sockshop-staging-k3s-server" "Name=instance-state-name,Values=running,stopped,pending" --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "Instance ID: $INSTANCE_ID"

echo ""
echo "=== Load Balancer Resources ==="
ALB_ARN=$(aws elbv2 describe-load-balancers --names sockshop-staging-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "ALB ARN: $ALB_ARN"

TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "Target Group ARN: $TG_ARN"

LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[0].ListenerArn' --output text)
echo "Listener ARN: $LISTENER_ARN"

echo ""
echo "=== Summary ==="
echo "All resources found successfully!"
