#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "Terraform Import Script for Staging"
echo "=========================================="
echo ""

# Change to staging directory
cd "$(dirname "$0")"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
    echo ""
fi

echo "Collecting AWS resource identifiers..."
echo ""

# VPC and networking
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sockshop-staging-vpc" --query 'Vpcs[0].VpcId' --output text)
echo "✓ VPC ID: $VPC_ID"

# Get subnets (in order)
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-vpc-public-*" --query 'Subnets | sort_by(@, &AvailabilityZone)[*].SubnetId' --output text)
SUBNET_ARRAY=($SUBNETS)
echo "✓ Found ${#SUBNET_ARRAY[@]} subnets"

# Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
echo "✓ Internet Gateway ID: $IGW_ID"

# Route Tables (public)
PUBLIC_RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-vpc-public" --query 'RouteTables[0].RouteTableId' --output text)
echo "✓ Public Route Table ID: $PUBLIC_RT_ID"

# Security Groups
K3S_SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-k3s-server" --query 'SecurityGroups[0].GroupId' --output text)
echo "✓ K3s Security Group ID: $K3S_SG_ID"

ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=sockshop-staging-alb" --query 'SecurityGroups[0].GroupId' --output text)
echo "✓ ALB Security Group ID: $ALB_SG_ID"

# IAM Resources - get the latest one
IAM_ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'sockshop-staging-k3s-server')] | sort_by(@, &CreateDate) | [-1].RoleName" --output text)
echo "✓ IAM Role Name: $IAM_ROLE_NAME"

IAM_PROFILE_NAME=$(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName, 'sockshop-staging-k3s-server')] | sort_by(@, &CreateDate) | [-1].InstanceProfileName" --output text)
echo "✓ IAM Instance Profile Name: $IAM_PROFILE_NAME"

# EC2 Instance
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sockshop-staging-k3s-server" "Name=instance-state-name,Values=running,stopped,pending" --query 'Reservations[0].Instances[0].InstanceId' --output text)
echo "✓ Instance ID: $INSTANCE_ID"

# Load Balancer Resources
ALB_ARN=$(aws elbv2 describe-load-balancers --names sockshop-staging-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "✓ ALB ARN: $ALB_ARN"

TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[0].TargetGroupArn' --output text)
echo "✓ Target Group ARN: $TG_ARN"

LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[0].ListenerArn' --output text)
echo "✓ Listener ARN: $LISTENER_ARN"

echo ""
echo "=========================================="
echo "Starting Terraform Import..."
echo "=========================================="
echo ""

# VPC Module resources need special handling
echo "Importing VPC module resources..."
terraform import 'module.vpc.aws_vpc.this[0]' "$VPC_ID" || echo "  (already imported or error)"
terraform import 'module.vpc.aws_internet_gateway.this[0]' "$IGW_ID" || echo "  (already imported or error)"
terraform import 'module.vpc.aws_route_table.public[0]' "$PUBLIC_RT_ID" || echo "  (already imported or error)"

# Import subnets
for i in "${!SUBNET_ARRAY[@]}"; do
    echo "Importing subnet $i: ${SUBNET_ARRAY[$i]}"
    terraform import "module.vpc.aws_subnet.public[$i]" "${SUBNET_ARRAY[$i]}" || echo "  (already imported or error)"
done

# Route table associations - need to get these
for i in "${!SUBNET_ARRAY[@]}"; do
    echo "Importing route table association for subnet $i"
    ASSOC_ID=$(aws ec2 describe-route-tables --route-table-ids "$PUBLIC_RT_ID" --query "RouteTables[0].Associations[?SubnetId=='${SUBNET_ARRAY[$i]}'].RouteTableAssociationId" --output text)
    if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
        terraform import "module.vpc.aws_route_table_association.public[$i]" "$ASSOC_ID" || echo "  (already imported or error)"
    fi
done

# Import route to internet gateway
terraform import 'module.vpc.aws_route.public_internet_gateway[0]' "${PUBLIC_RT_ID}_0.0.0.0/0" || echo "  (already imported or error)"

echo ""
echo "Importing Security Groups..."
terraform import aws_security_group.k3s_server "$K3S_SG_ID" || echo "  (already imported or error)"
terraform import aws_security_group.alb "$ALB_SG_ID" || echo "  (already imported or error)"

echo ""
echo "Importing IAM Resources..."
terraform import aws_iam_role.k3s_server "$IAM_ROLE_NAME" || echo "  (already imported or error)"
terraform import aws_iam_role_policy_attachment.k3s_server_ssm "${IAM_ROLE_NAME}/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" || echo "  (already imported or error)"
terraform import aws_iam_instance_profile.k3s_server "$IAM_PROFILE_NAME" || echo "  (already imported or error)"

echo ""
echo "Importing EC2 Instance..."
terraform import aws_instance.k3s_server "$INSTANCE_ID" || echo "  (already imported or error)"

echo ""
echo "Importing Load Balancer Resources..."
terraform import aws_lb.staging_alb "$ALB_ARN" || echo "  (already imported or error)"
terraform import aws_lb_target_group.app "$TG_ARN" || echo "  (already imported or error)"
terraform import aws_lb_target_group_attachment.app "${TG_ARN}/${INSTANCE_ID}/30080" || echo "  (already imported or error)"
terraform import aws_lb_listener.http "$LISTENER_ARN" || echo "  (already imported or error)"

echo ""
echo "=========================================="
echo "Import Complete!"
echo "=========================================="
echo ""
echo "Running terraform plan to verify state..."
terraform plan
