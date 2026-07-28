# Troubleshooting Guide - Sock Shop Not Accessible

## 🚨 Critical Issues to Fix First

### 1. System Clock Issue (MUST FIX FIRST!)

**Problem**: AWS commands fail with "Signature expired" error
**Cause**: Your Mac's system clock is incorrect (showing future dates)

**Fix**:
```bash
# Option 1: Command line
sudo sntp -sS time.apple.com

# Option 2: System Settings
# Go to: System Settings → General → Date & Time
# Turn ON "Set time and date automatically"
```

**Verify**:
```bash
date
# Should show current date/time, not future dates
```

---

## 🔍 Why the Application Isn't Working

### Current Status
- ❌ **ALB URL**: http://sockshop-staging-alb-812471275.eu-central-1.elb.amazonaws.com/
- ❌ **Direct URL**: http://3.65.228.51:30080/
- **Error**: 504 Gateway Timeout or Connection Timeout

### Root Causes

**The application isn't working because:**

1. **K3s may not be fully installed yet**
   - The instance was resized from t3.micro → t3.small
   - User-data script runs K3s installation
   - Takes 3-5 minutes after instance starts

2. **Sock Shop pods haven't started**
   - 14 microservices need to download images
   - Each pod needs to start and pass health checks
   - Takes 5-10 minutes after K3s is ready

3. **No service listening on port 30080**
   - The Sock Shop `front-end` service uses NodePort 30080
   - ALB routes to this port
   - Port only responds when front-end pod is running

---

## ✅ Step-by-Step Fix

### Step 1: Fix Your System Clock (DO THIS FIRST!)

```bash
sudo sntp -sS time.apple.com
date  # Verify it shows correct time
```

### Step 2: Check if K3s is Running

```bash
aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl is-active k3s"]' \
  --region eu-central-1 \
  --query "Command.CommandId" \
  --output text
```

Wait 5 seconds, then get the result with the command ID returned above.

**Expected output**: `active`

### Step 3: Check User-Data Log

```bash
aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["tail -50 /var/log/user-data.log"]' \
  --region eu-central-1 \
  --query "Command.CommandId" \
  --output text
```

**Look for**: "K3s installation complete!"

### Step 4: Deploy Sock Shop (If Not Already Deployed)

```bash
aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["kubectl apply -f https://raw.githubusercontent.com/microservices-demo/microservices-demo/master/deploy/kubernetes/complete-demo.yaml"]' \
  --region eu-central-1 \
  --query "Command.CommandId" \
  --output text
```

### Step 5: Wait for Pods to Start (10-15 minutes)

Check pod status:
```bash
aws ssm send-command \
  --instance-ids i-0dd60330cc4a99b2c \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["kubectl get pods -n sock-shop"]' \
  --region eu-central-1 \
  --query "Command.CommandId" \
  --output text
```

**What you want to see**:
```
NAME                       READY   STATUS    RESTARTS   AGE
front-end-xxx              1/1     Running   0          5m
carts-xxx                  1/1     Running   0          5m
...all pods Running...
```

### Step 6: Test Direct Connection

```bash
# Test if port 30080 responds
curl -v http://3.65.228.51:30080/ --max-time 5
```

**Expected**: HTML response (Sock Shop homepage)

### Step 7: Check ALB Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:414772274298:targetgroup/ssstg-20260422065437631200000004/053bfb4a7553b263 \
  --region eu-central-1
```

**Expected**: `"State": "healthy"`

---

## 🔧 Alternative: Manual Deployment via EC2 Instance Connect

If SSM isn't working, you can connect directly:

### Option 1: AWS Console
1. Go to EC2 → Instances
2. Select: **sockshop-staging-k3s-server**
3. Click: **Connect** → **EC2 Instance Connect**
4. Click: **Connect**

Then run:
```bash
# Check K3s
systemctl status k3s

# Deploy Sock Shop
kubectl apply -f https://raw.githubusercontent.com/microservices-demo/microservices-demo/master/deploy/kubernetes/complete-demo.yaml

# Watch pods start
kubectl get pods -n sock-shop -w
```

### Option 2: SSH (If you configured a key)

```bash
# Note: You didn't configure SSH key, so this won't work unless you add one
ssh ubuntu@3.65.228.51
```

---

## 📊 Expected Timeline

| Time | Status | What's Happening |
|------|--------|------------------|
| **0 min** | Instance resized | K3s installing |
| **3-5 min** | K3s ready | Can deploy apps |
| **5-10 min** | Pods starting | Downloading images |
| **10-15 min** | ✅ Working | App accessible |

---

## 🐛 Common Issues

### Issue: "Signature expired" Error
**Cause**: System clock is wrong
**Fix**: `sudo sntp -sS time.apple.com`

### Issue: Pods stuck in "Pending"
**Cause**: Insufficient resources
**Fix**: Instance already upgraded to t3.small (2GB), should be enough

### Issue: Pods stuck in "ImagePullBackOff"
**Cause**: Can't download Docker images
**Check**: Internet connectivity from instance

### Issue: Pods "CrashLoopBackOff"
**Cause**: Application errors, dependency issues
**Fix**: Check specific pod logs:
```bash
kubectl logs <pod-name> -n sock-shop
```

### Issue: Target always "unhealthy"
**Possible causes**:
1. Front-end pod not running
2. Service not created correctly
3. Security group blocking port 30080
4. Health check path incorrect

**Check service**:
```bash
kubectl get svc -n sock-shop front-end
# Should show NodePort: 30080
```

---

## 🆘 Nuclear Option: Redeploy Everything

If nothing works after 30 minutes:

```bash
cd /Users/mobius/Desktop/sock-shop-devops/staging

# Destroy and recreate
terraform destroy -auto-approve
terraform apply -auto-approve
```

**Warning**: This will:
- Delete the instance
- Create a new one
- Start from scratch
- Take 15-20 minutes total

---

## 📱 Quick Status Check Script

After fixing your system clock, run:

```bash
cd /Users/mobius/Desktop/sock-shop-devops
./check-deployment-status.sh
```

This checks:
- ✅ Target health
- ✅ HTTP response codes
- ✅ Pod status

---

## 🎯 Success Criteria

You'll know it's working when:

1. ✅ `curl http://3.65.228.51:30080/` returns HTML
2. ✅ Target health shows "healthy"
3. ✅ Browser shows Sock Shop homepage at ALB URL
4. ✅ All 14 pods show "Running" status

---

## 📞 Need Help?

If stuck after trying everything:

1. Check the GitHub Actions logs (if workflow ran)
2. Review instance user-data logs
3. Check CloudWatch logs (if configured)
4. Post issue with:
   - Output of `./check-deployment-status.sh`
   - Pod status
   - Target health status

---

## 🔗 Useful Links

- **EC2 Console**: https://eu-central-1.console.aws.amazon.com/ec2/home?region=eu-central-1#Instances:
- **Load Balancers**: https://eu-central-1.console.aws.amazon.com/ec2/home?region=eu-central-1#LoadBalancers:
- **GitHub Actions**: https://github.com/HiufaiLau/sock-shop-devops/actions
- **Sock Shop Docs**: https://microservices-demo.github.io/

---

