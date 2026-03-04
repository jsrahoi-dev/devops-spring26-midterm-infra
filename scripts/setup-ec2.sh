#!/bin/bash
# setup-ec2.sh - Initial setup for QA/RC EC2 instances

set -e

echo "Installing Docker..."
sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

echo "Installing docker-compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

echo "Creating application directory..."
mkdir -p /home/ec2-user/color-app
cd /home/ec2-user/color-app

echo "Setup complete! Next steps:"
echo "1. Configure .env file with RDS credentials"
echo "2. Authenticate Docker to ECR"
echo "3. Run deployment script"
