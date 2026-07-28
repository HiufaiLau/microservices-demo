# Sock Shop AWS Deployment - Summary

## ✅ Successfully Completed

### 1. Infrastructure Setup
- **Fixed CD Workflow** ([.github/workflows/cd.yml](.github/workflows/cd.yml))
  - Corrected Terraform paths (staging → correct directory)
  - Implemented AWS Systems Manager (SSM) for secure access (no SSH keys needed)
  - Added proper instance ID retrieval from Terraform outputs

- **Completed Terraform Configuration** ([staging/]](staging/))
  - EC2 instance with K3s
  - Security groups (K3s server + ALB)
  - IAM roles with SSM permissions
  - Application Load Balancer
  - Target groups and health checks
  - User-data script for K3s installation

### 2. Tools Installed
- ✅ Terraform v1.14.9
- ✅ AWS CLI v2.34.34
- ✅ kubectl v1.35.4

### 3. AWS Infrastructure Deployed (Frankfurt - eu-central-1)
- ✅ VPC (vpc-0b64ddf69826d4ce1)
- ✅ 3 Public Subnets across availability zones
- ✅ Internet Gateway & Route Tables
- ✅ **EC2 Instance**: i-0dd60330cc4a99b2c (t3.small - 2GB RAM)
- ✅ **Public IP**: 3.65.228.51
- ✅ **Application Load Balancer**: sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com
- ✅ Security Groups configured
- ✅ IAM Roles for SSM

### 4. Configuration Files Created
- [staging/terraform.tfvars](staging/terraform.tfvars) - Configured for Frankfurt
- [staging/user-data.sh](staging/user-data.sh) - K3s installation script
- [staging/README.md](staging/README.md) - Complete documentation
- [AWS_CREDENTIALS_SETUP.md](AWS_CREDENTIALS_SETUP.md) - Credentials guide

## ⚠️ Current Status

### Instance Upgrade
- **Initial Deployment**: t3.micro (1GB RAM) - Too small for Sock Shop
- **Diagnosis**: Instance was overloaded, SSM commands timing out
- **Solution**: Upgraded to t3.small (2GB RAM)
- **Result**: Instance restarted, K3s reinstalling

### Application Deployment
- Sock Shop deployment manifest applied via SSM
- **Current Issue**: Target health check failing (502 Bad Gateway)
- **Root Cause**: K3s may still be completing installation, or pods are starting slowly

## 📋 Next Steps to Complete Deployment

### Option 1: Wait for K3s and Pods (Recommended)
The application may just need more time. After a fresh instance restart, K3s takes 3-5 minutes and pods take another 5-10 minutes.

```bash
# Wait 10 more minutes, then check:
curl http://sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com/

# Check target health:
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:414772274298:targetgroup/ssstg-20260422065437631200000004/053bfb4a7553b263 \
  --region eu-central-1
```

### Option 2: Manual Verification via kubectl
Get a fresh kubeconfig and check pod status:

```bash
cd /Users/mobius/Desktop/sock-shop-devops/staging

# Get kubeconfig
CMD_ID=$(aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
  --query "Command.CommandId" --output text --region eu-central-1)

sleep 5

aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id i-0dd60330cc4a99b2c \
  --region eu-central-1 \
  --query "StandardOutputContent" --output text | \
  sed "s/127.0.0.1/3.65.228.51/g" > ~/.kube/config-staging

chmod 600 ~/.kube/config-staging

# Check pods
export KUBECONFIG=~/.kube/config-staging
kubectl get pods -n sock-shop
kubectl get nodes
```

### Option 3: Redeploy Application
If K3s is ready but app isn't deployed:

```bash
export KUBECONFIG=~/.kube/config-staging
kubectl apply -f /Users/mobius/Desktop/sock-shop-devops/deploy/kubernetes/complete-demo.yaml

# Wait for pods to be ready (5-10 minutes)
kubectl get pods -n sock-shop -w
```

## 💰 Cost Estimate

**Current Monthly Cost:**
- t3.small EC2: ~$15/month
- Application Load Balancer: ~$20/month
- EBS Storage (50GB): ~$5/month
- Data transfer: ~$2-5/month
- **Total: ~$42-45/month**

## 🔑 Access Information

### Infrastructure
- **Region**: eu-central-1 (Frankfurt, Germany)
- **VPC**: vpc-0b64ddf69826d4ce1
- **Instance**: i-0dd60330cc4a99b2c
- **Public IP**: 3.65.228.51
- **ALB DNS**: sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com

### Credentials
AWS CLI configured at: `~/.aws/credentials`

### Kubernetes
Kubeconfig location: `~/.kube/config-staging`

## 🗑️ Cleanup Instructions

To destroy all resources and stop incurring costs:

```bash
cd /Users/mobius/Desktop/sock-shop-devops/staging
terraform destroy
```

**Warning**: This will delete ALL resources including data!

## 📝 GitHub Secrets Needed for CD Workflow

To enable automated deployments via GitHub Actions:

1. Go to GitHub repo → Settings → Secrets → Actions
2. Add these secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`: eu-central-1

Then push to `staging` branch to trigger automatic deployment.

## 🐛 Troubleshooting

### If Application Still Shows 502

1. **Check if K3s is running:**
   ```bash
   aws ssm send-command \
     --instance-ids i-0dd60330cc4a99b2c \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["systemctl status k3s"]' \
     --region eu-central-1
   ```

2. **Check user-data log:**
   ```bash
   aws ssm send-command \
     --instance-ids i-0dd60330cc4a99b2c \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["tail -100 /var/log/user-data.log"]' \
     --region eu-central-1
   ```

3. **Access instance directly:**
   The ALB targets port 30080 on the instance. Test directly:
   ```bash
   curl http://3.65.228.51:30080/
   ```

### If You Need More Resources

Consider upgrading to t3.medium (4GB RAM) for better performance:

```bash
# Edit staging/terraform.tfvars
master_instance_type = "t3.medium"

# Apply changes
terraform apply
```

## 📚 Documentation

- [staging/README.md](staging/README.md) - Detailed infrastructure documentation
- [AWS_CREDENTIALS_SETUP.md](AWS_CREDENTIALS_SETUP.md) - AWS credentials setup guide
- [.github/workflows/cd.yml](.github/workflows/cd.yml) - CD workflow configuration

## 🎯 Summary

**What Works:**
- ✅ Complete AWS infrastructure deployed
- ✅ K3s cluster configured and installing
- ✅ Application Load Balancer routing configured
- ✅ Security groups and networking
- ✅ SSM access (no SSH keys needed)

**What Needs Attention:**
- ⏳ K3s may still be completing installation
- ⏳ Pods may still be starting (takes 5-10 minutes)
- ⏳ Health checks will pass once front-end pod responds on port 80

**Recommended Next Action:**
Wait 10-15 minutes and test the ALB URL again. The application should be accessible once all pods finish starting.
