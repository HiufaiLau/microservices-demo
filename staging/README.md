# Staging Environment - AWS Terraform Configuration

This directory contains Terraform configuration to deploy a K3s (lightweight Kubernetes) cluster on AWS for the Sock Shop staging environment.

## Architecture

- **VPC**: Custom VPC with public subnets across 3 availability zones
- **EC2 Instance**: Single t3.large instance running K3s
- **Application Load Balancer**: ALB to route traffic to the K3s NodePort
- **Security Groups**: Configured for HTTP/HTTPS traffic and K3s API access
- **IAM Roles**: EC2 instance profile with SSM permissions (no SSH keys needed!)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.5.0
4. **GitHub Secrets** configured (for CI/CD):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

## Configuration

### Step 1: Configure terraform.tfvars

The [terraform.tfvars](terraform.tfvars) file has been created with default values. Update these settings:

```hcl
# Change to your preferred region
aws_region = "us-east-1"

# Update availability zones to match your region
azs = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

# Optional: Restrict K3s API access to your IP
# Get your IP: curl ifconfig.me
bastion_cidr_block = "YOUR.IP.ADDRESS/32"
```

### Step 2: Initialize Terraform

```bash
cd staging
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

### Step 4: Apply Configuration

```bash
terraform apply
```

## Accessing the Cluster

### Option 1: Using AWS Systems Manager (Recommended - No SSH Key Needed!)

```bash
# Get the instance ID
INSTANCE_ID=$(terraform output -raw server_instance_id)

# Fetch kubeconfig using SSM
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
  --query "Command.CommandId" --output text)

# Wait for command to complete
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID"

# Save kubeconfig
SERVER_IP=$(terraform output -raw server_public_ip)
aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "StandardOutputContent" --output text | \
  sed "s/127.0.0.1/${SERVER_IP}/g" > ~/.kube/config-staging

# Use the config
export KUBECONFIG=~/.kube/config-staging
kubectl get nodes
```

### Option 2: Using SSH (Optional)

If you configured a `key_name` in terraform.tfvars:

```bash
SERVER_IP=$(terraform output -raw server_public_ip)
ssh ubuntu@$SERVER_IP
sudo cat /etc/rancher/k3s/k3s.yaml
```

## Access the Application

After deployment completes:

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Access the application
curl http://$(terraform output -raw alb_dns_name)
```

## Resources Created

| Resource | Description |
|----------|-------------|
| VPC | Custom VPC with DNS support |
| Public Subnets | 3 public subnets across AZs |
| Internet Gateway | For public internet access |
| EC2 Instance | t3.large running Ubuntu 22.04 + K3s |
| Security Groups | For K3s server and ALB |
| IAM Role | For SSM access (no SSH needed) |
| Application Load Balancer | Routes traffic to K3s NodePort 30080 |
| Target Group | Health checks and routing |

## Outputs

After `terraform apply`, you'll see:

- `vpc_id`: VPC identifier
- `public_subnets`: List of public subnet IDs
- `alb_dns_name`: **Access your app here!**
- `server_public_ip`: K3s server public IP
- `server_instance_id`: EC2 instance ID for SSM
- `kubeconfig_command`: SSM command to fetch kubeconfig

## CI/CD Integration

The [.github/workflows/cd.yml](../.github/workflows/cd.yml) workflow automatically:

1. Runs Terraform apply when you push to `staging` branch
2. Uses AWS SSM (no SSH keys required!) to fetch kubeconfig
3. Deploys the Sock Shop application
4. Runs smoke tests

## Cost Estimate

Approximate monthly cost (us-east-1):

- t3.large EC2: ~$60/month
- Application Load Balancer: ~$20/month
- EBS Storage (50GB): ~$5/month
- Data transfer: Variable

**Total: ~$85-100/month**

## Troubleshooting

### SSM Agent Not Available

If SSM isn't working:
1. Check that the instance has the IAM role attached
2. Wait 2-3 minutes after instance creation for SSM agent to register
3. Check Systems Manager → Fleet Manager in AWS Console

### K3s Not Ready

Check the user data logs:
```bash
aws ssm start-session --target $(terraform output -raw server_instance_id)
sudo cat /var/log/user-data.log
```

### Application Not Accessible

Check ALB target health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names sockshop-staging-app --query 'TargetGroups[0].TargetGroupArn' --output text)
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including data!

## Security Notes

- ✅ **No SSH keys required** - Uses AWS SSM for secure access
- ✅ **IAM-based authentication** - More secure than SSH keys
- ✅ **Security groups** configured for minimal exposure
- ⚠️ **ALB is public** - Consider adding authentication for production
- ⚠️ **Update bastion_cidr_block** - Restrict K3s API access to your IP

## Next Steps

1. **Add HTTPS**: Configure ACM certificate and HTTPS listener
2. **Add monitoring**: CloudWatch dashboards and alarms
3. **Add backup**: Automated EBS snapshots
4. **Create production**: Copy this directory to `production/` with prod values
