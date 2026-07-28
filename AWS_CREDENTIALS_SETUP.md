# AWS Credentials Setup Guide

You need to configure AWS credentials before Terraform can create resources. Here are your options:

## Option 1: Using AWS CLI Configure (Recommended - Easiest)

Run this command in your terminal and follow the prompts:

```bash
aws configure
```

You'll be asked for:
1. **AWS Access Key ID**: Get this from AWS IAM Console
2. **AWS Secret Access Key**: Get this from AWS IAM Console
3. **Default region name**: Enter `eu-central-1` (Frankfurt)
4. **Default output format**: Press Enter (or type `json`)

### How to Get AWS Access Keys:

1. Log into AWS Console: https://console.aws.amazon.com/
2. Go to **IAM** → **Users** → Click your username
3. Click **Security credentials** tab
4. Click **Create access key**
5. Select **Command Line Interface (CLI)**
6. Click **Next** → **Create access key**
7. **Copy both keys** (you won't see the secret key again!)

## Option 2: Using Environment Variables (Temporary - For Current Session)

Run these commands in your terminal (replace with your actual keys):

```bash
export AWS_ACCESS_KEY_ID="your-access-key-here"
export AWS_SECRET_ACCESS_KEY="your-secret-key-here"
export AWS_REGION="eu-central-1"
```

**Note**: These will only last until you close your terminal window.

To make them permanent, add them to your `~/.zshrc` file:

```bash
echo 'export AWS_ACCESS_KEY_ID="your-access-key-here"' >> ~/.zshrc
echo 'export AWS_SECRET_ACCESS_KEY="your-secret-key-here"' >> ~/.zshrc
echo 'export AWS_REGION="eu-central-1"' >> ~/.zshrc
source ~/.zshrc
```

## Option 3: Using AWS Credentials File (Manual)

Create or edit the file: `~/.aws/credentials`

```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = your-access-key-here
aws_secret_access_key = your-secret-key-here
EOF

cat > ~/.aws/config <<EOF
[default]
region = eu-central-1
output = json
EOF
```

## Verify Your Configuration

After configuring, test it:

```bash
# Check if credentials are configured
aws sts get-caller-identity

# You should see something like:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

## For GitHub Actions (CD Workflow)

The CD workflow needs these secrets in your GitHub repository:

1. Go to your GitHub repo
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   - **Name**: `AWS_ACCESS_KEY_ID`
     **Value**: Your AWS access key

   - **Name**: `AWS_SECRET_ACCESS_KEY`
     **Value**: Your AWS secret access key

   - **Name**: `AWS_REGION`
     **Value**: `eu-central-1`

## Security Best Practices

⚠️ **IMPORTANT**:
- Never commit credentials to Git
- Use IAM users with minimal required permissions
- Enable MFA (Multi-Factor Authentication) on your AWS account
- Rotate access keys regularly
- Consider using AWS SSO for production setups

## IAM Permissions Required

Your IAM user/role needs these permissions:
- EC2 (create instances, security groups)
- VPC (create VPCs, subnets, internet gateways)
- ELB (create load balancers, target groups)
- IAM (create roles, instance profiles)
- SSM (Systems Manager access)

You can use the **AdministratorAccess** policy for testing, but create a custom policy for production.

## Troubleshooting

### "No valid credential sources found"
- Run `aws configure` to set up credentials
- Or set environment variables as shown above

### "Access Denied" errors
- Check your IAM user has sufficient permissions
- Verify the credentials are correct

### "Region not supported"
- Make sure you set region to `eu-central-1` (Frankfurt)

## Next Steps

After configuring credentials:

```bash
cd /Users/mobius/Desktop/sock-shop-devops/staging

# Validate configuration
terraform validate

# See what will be created
terraform plan

# Create the infrastructure (when ready)
terraform apply
```
