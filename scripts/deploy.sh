#!/bin/bash
set -e

# Deploy script for Color Perception SPA
# Usage: ./deploy.sh <instance-id> <region> <ecr-image>

INSTANCE_ID=${1:-"i-0db4adb06f60fb867"}
REGION=${2:-"us-east-2"}
ECR_IMAGE=${3:-"899088266694.dkr.ecr.us-east-2.amazonaws.com/color-perception-spa:latest"}

echo "🚀 Deploying to EC2 instance: $INSTANCE_ID"

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "📍 Instance IP: $PUBLIC_IP"

# Create deployment script
cat > /tmp/remote-deploy.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
set -e

ECR_IMAGE="$1"
REGION="$2"
DB_HOST="$3"
DB_USER="$4"
DB_PASSWORD="$5"
DB_NAME="$6"
SESSION_SECRET="$7"

echo "🔐 Authenticating to ECR..."
aws ecr get-login-password --region $REGION | \
  sudo docker login --username AWS --password-stdin \
  $(echo $ECR_IMAGE | cut -d'/' -f1)

echo "📥 Pulling latest image..."
sudo docker pull $ECR_IMAGE

echo "🛑 Stopping existing container..."
sudo docker stop color-app 2>/dev/null || true
sudo docker rm color-app 2>/dev/null || true

echo "🚀 Starting new container..."
sudo docker run -d \
  --name color-app \
  -p 80:3000 \
  -p 443:3000 \
  -e DB_HOST=$DB_HOST \
  -e DB_USER=$DB_USER \
  -e DB_PASSWORD=$DB_PASSWORD \
  -e DB_NAME=$DB_NAME \
  -e SESSION_SECRET=$SESSION_SECRET \
  -e NODE_ENV=production \
  --restart unless-stopped \
  $ECR_IMAGE

echo "✅ Deployment complete!"
sudo docker ps | grep color-app
DEPLOY_SCRIPT

chmod +x /tmp/remote-deploy.sh

# Copy and execute deployment script
echo "📤 Copying deployment script to EC2..."
scp -i ~/.ssh/color-perception-key.pem \
  -o StrictHostKeyChecking=no \
  /tmp/remote-deploy.sh \
  ec2-user@$PUBLIC_IP:/tmp/deploy.sh

echo "⚙️  Executing deployment on EC2..."
ssh -i ~/.ssh/color-perception-key.pem \
  -o StrictHostKeyChecking=no \
  ec2-user@$PUBLIC_IP \
  "bash /tmp/deploy.sh \
    $ECR_IMAGE \
    $REGION \
    ${DB_HOST:-color-perception-db.c908ea8wy9z2.us-east-2.rds.amazonaws.com} \
    ${DB_USER:-admin} \
    ${DB_PASSWORD:-AKIA5CVOWGXDHXAIV3ED} \
    ${DB_NAME:-color_app} \
    ${SESSION_SECRET:-temp_secret_change_later}"

echo ""
echo "✅ Deployment successful!"
echo "🌐 Application available at: http://$PUBLIC_IP"
