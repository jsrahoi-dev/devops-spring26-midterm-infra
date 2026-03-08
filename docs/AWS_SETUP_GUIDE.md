# AWS Setup Guide - Step by Step

This guide walks you through setting up AWS infrastructure for the Color Perception SPA project.

## Prerequisites
- Fresh AWS account
- Domain name from Name.com (or ready to purchase one)
- GitHub account with access to both repos

---

## Phase 1: AWS Account Setup (15 minutes)

### 1.1 Create IAM User for CLI Access

**Why:** You need programmatic access to AWS for local development and GitHub Actions.

1. Log into AWS Console: https://console.aws.amazon.com
2. Navigate to IAM → Users → Create User
3. Username: `devops-midterm-deploy`
4. Enable: **AWS credential type** → ✅ Access key - Programmatic access
5. Click **Next**

### 1.2 Attach Policies

Attach these managed policies to the user:
- `AmazonEC2ContainerRegistryFullAccess` (for ECR)
- `AmazonEC2FullAccess` (for EC2 instances)
- `AmazonRDSFullAccess` (for RDS)
- `AmazonRoute53FullAccess` (for DNS)
- `AmazonVPCFullAccess` (for networking)

> **Note:** For production, you'd use more restrictive custom policies. This is for learning.

### 1.3 Save Credentials

1. Download the CSV with access keys
2. Save it securely - you'll need it later

### 1.4 Install & Configure AWS CLI

```bash
# Install (macOS)
brew install awscli

# Configure with your credentials
aws configure
# AWS Access Key ID: [paste from CSV]
# AWS Secret Access Key: [paste from CSV]
# Default region: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/devops-midterm-deploy"
}
```

---

## Phase 2: RDS MySQL Setup (20 minutes)

### 2.1 Create RDS MySQL Instance

1. Go to: **RDS Console** → **Create database**

2. **Engine options:**
   - Engine type: MySQL
   - Version: MySQL 8.0.x (latest)
   - Templates: **Free tier** (if eligible) or **Dev/Test**

3. **Settings:**
   - DB instance identifier: `color-perception-db`
   - Master username: `admin`
   - Master password: (create a strong password - save it!)
   - Confirm password

4. **Instance configuration:**
   - DB instance class: `db.t3.micro` or `db.t4g.micro` (free tier eligible)

5. **Storage:**
   - Storage type: General Purpose SSD (gp3)
   - Allocated storage: 20 GB
   - ✅ Enable storage autoscaling (max: 100 GB)

6. **Connectivity:**
   - VPC: Default VPC
   - Public access: **Yes** (for now - we'll secure it with security groups)
   - VPC security group: Create new
   - New security group name: `color-perception-db-sg`
   - Availability Zone: No preference

7. **Database authentication:**
   - Password authentication

8. **Additional configuration:**
   - Initial database name: `color_app`
   - ✅ Enable automated backups (retention: 7 days)
   - Backup window: No preference
   - Monitoring: Default

9. Click **Create database**

⏱️ **Wait time:** 10-15 minutes for the database to become available

### 2.2 Configure Security Group

While waiting, configure the security group:

1. Go to: **EC2 Console** → **Security Groups**
2. Find: `color-perception-db-sg`
3. Edit **Inbound rules:**

Add rules:
```
Type: MySQL/Aurora
Protocol: TCP
Port: 3306
Source: Custom → [We'll add EC2 security group later]
Description: Allow from EC2 instances

Type: MySQL/Aurora
Protocol: TCP
Port: 3306
Source: My IP → [Your current IP for testing]
Description: Allow from local machine for setup
```

4. Click **Save rules**

### 2.3 Initialize Database Schema

Once RDS is available:

1. Get the endpoint:
```bash
aws rds describe-db-instances \
  --db-instance-identifier color-perception-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

Save this endpoint (e.g., `color-perception-db.xxxxxx.us-east-1.rds.amazonaws.com`)

2. Connect and initialize:
```bash
# From your source repo backend directory
cd /Users/unotest/dev/grad_school/devops/midterm/devops-spring26-midterm-source/backend

# Connect to RDS
mysql -h <RDS_ENDPOINT> -u admin -p color_app

# Run schema and seed
source db/schema.sql
source db/seed.sql

# Verify
SHOW TABLES;
SELECT COUNT(*) FROM colors;

# Exit
exit
```

---

## Phase 3: ECR Setup (5 minutes)

### 3.1 Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name color-perception-spa \
  --region us-east-1

# Save the repository URI from the output
# Format: 123456789012.dkr.ecr.us-east-1.amazonaws.com/color-perception-spa
```

### 3.2 Test Local Push (Optional)

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and tag
cd /Users/unotest/dev/grad_school/devops/midterm/devops-spring26-midterm-source
docker build -t color-perception-spa .
docker tag color-perception-spa:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/color-perception-spa:test

# Push
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/color-perception-spa:test
```

---

## Phase 4: EC2 Setup - QA Instance (30 minutes)

### 4.1 Create Key Pair

```bash
# Create SSH key pair
aws ec2 create-key-pair \
  --key-name color-perception-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/color-perception-key.pem

# Set permissions
chmod 400 ~/.ssh/color-perception-key.pem
```

### 4.2 Create Security Group for EC2

```bash
# Create security group
aws ec2 create-security-group \
  --group-name color-perception-ec2-sg \
  --description "Security group for Color Perception EC2 instances" \
  --output text

# Save the security group ID (sg-xxxxx)
SG_ID="<paste-sg-id-here>"

# Allow SSH (your IP only - for setup)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $(curl -s ifconfig.me)/32

# Allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### 4.3 Update RDS Security Group

```bash
# Get RDS security group ID
RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier color-perception-db \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# Allow EC2 instances to connect to RDS
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 3306 \
  --source-group $SG_ID
```

### 4.4 Launch QA EC2 Instance

```bash
# Get latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name color-perception-key \
  --security-group-ids $SG_ID \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=color-perception-qa},{Key=Environment,Value=qa}]' \
  --user-data file://user-data.sh

# Get instance ID from output, then get public IP
INSTANCE_ID="<paste-instance-id>"
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

**Note:** Create `user-data.sh` first (see next step)

### 4.5 EC2 User Data Script

Create this file before launching the instance:

```bash
cat > user-data.sh << 'EOF'
#!/bin/bash
# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI (should be pre-installed on AL2023)
yum install -y aws-cli

# Create app directory
mkdir -p /app
chown ec2-user:ec2-user /app
EOF
```

### 4.6 SSH into QA Instance and Verify

```bash
# SSH in
ssh -i ~/.ssh/color-perception-key.pem ec2-user@<EC2_PUBLIC_IP>

# Verify Docker
docker --version
docker-compose --version
aws --version

# Exit
exit
```

---

## Phase 5: Route53 & Domain Setup (30-60 minutes)

### 5.1 Purchase Domain at Name.com

1. Go to https://www.name.com
2. Search and purchase a domain (e.g., `yourname-color-app.com`)
3. Complete purchase

### 5.2 Create Hosted Zone in Route53

```bash
# Create hosted zone
aws route53 create-hosted-zone \
  --name yourname-color-app.com \
  --caller-reference $(date +%s)

# Note the NameServers from the output
```

### 5.3 Update Name.com Nameservers

1. Log into Name.com
2. Go to your domain → DNS Settings
3. Change nameservers to the 4 AWS nameservers from Route53:
   - ns-xxxx.awsdns-xx.com
   - ns-xxxx.awsdns-xx.co.uk
   - ns-xxxx.awsdns-xx.net
   - ns-xxxx.awsdns-xx.org
4. Save changes

⏱️ **Wait time:** 1-48 hours for DNS propagation (usually 15-30 minutes)

### 5.4 Create A Record for QA

```bash
# Get QA instance public IP
QA_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=color-perception-qa" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# Get hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`yourname-color-app.com.`].Id' \
  --output text | cut -d'/' -f3)

# Create change batch
cat > change-batch.json << EOF
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "qa.yourname-color-app.com",
      "Type": "A",
      "TTL": 300,
      "ResourceRecords": [{"Value": "$QA_IP"}]
    }
  }]
}
EOF

# Create record
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://change-batch.json
```

### 5.5 Verify DNS

```bash
# Wait a few minutes, then test
dig qa.yourname-color-app.com +short
# Should return the QA instance IP
```

---

## Phase 6: GitHub Actions Setup (20 minutes)

### 6.1 Set Up OIDC Provider (Recommended)

**Why:** Avoid storing long-lived AWS credentials in GitHub

1. Go to: **IAM Console** → **Identity providers** → **Add provider**
2. Provider type: **OpenID Connect**
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click **Add provider**

### 6.2 Create IAM Role for GitHub Actions

```bash
# Create trust policy
cat > github-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:jsrahoi-dev/devops-spring26-midterm-infra:*"
        }
      }
    }
  ]
}
EOF

# Replace YOUR_ACCOUNT_ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i '' "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" github-trust-policy.json

# Create role
aws iam create-role \
  --role-name GitHubActionsDeployRole \
  --assume-role-policy-document file://github-trust-policy.json

# Attach policies to the role
aws iam attach-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
```

### 6.3 Configure GitHub Secrets

Go to your **infra repo** on GitHub:
`https://github.com/jsrahoi-dev/devops-spring26-midterm-infra/settings/secrets/actions`

Add these secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `AWS_ACCOUNT_ID` | `123456789012` | Your AWS account ID |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/GitHubActionsDeployRole` | OIDC role ARN |
| `ECR_REPOSITORY` | `color-perception-spa` | ECR repo name |
| `QA_INSTANCE_ID` | `i-xxxxx` | QA EC2 instance ID |
| `QA_HOST` | `qa.yourname-color-app.com` | QA domain |
| `DB_HOST` | `color-perception-db.xxxxx.rds.amazonaws.com` | RDS endpoint |
| `DB_NAME` | `color_app` | Database name |
| `DB_USER` | `admin` | Database user |
| `DB_PASSWORD` | `your-password` | Database password |
| `SESSION_SECRET` | (generate random string) | Session secret |

To get values:
```bash
# Account ID
aws sts get-caller-identity --query Account --output text

# QA Instance ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=color-perception-qa" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text

# RDS Endpoint
aws rds describe-db-instances \
  --db-instance-identifier color-perception-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Generate session secret
openssl rand -base64 32
```

---

## Phase 7: SSL Setup with Let's Encrypt

We'll do this after the first deployment is working. For now, the app will run on HTTP.

---

## Summary - What You Should Have Now

✅ **AWS Account:**
- IAM user with programmatic access
- AWS CLI configured

✅ **RDS:**
- MySQL 8.0 instance running
- Database initialized with schema and seed data
- Security group configured

✅ **ECR:**
- Repository created for Docker images

✅ **EC2:**
- QA instance running
- Security groups configured
- SSH access working

✅ **Route53:**
- Hosted zone created
- Domain nameservers updated
- DNS record for QA instance

✅ **GitHub:**
- OIDC provider configured
- IAM role for GitHub Actions
- Secrets configured

---

## Next Steps

1. **Test manual deployment** to QA instance
2. **Configure SSL** with Let's Encrypt
3. **Test the nightly build workflow**
4. **Set up monitoring** (optional)

Would you like me to help with the next phase?
