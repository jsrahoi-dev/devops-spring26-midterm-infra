#!/bin/bash
# deploy.sh - Deploy application from ECR to EC2

set -e

IMAGE_TAG=${1:-latest}
ECR_REGISTRY=${ECR_REGISTRY}
ECR_REPOSITORY=${ECR_REPOSITORY:-color-app}

echo "Deploying image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

# Authenticate to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Pull latest image
docker pull ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}

# Stop existing container
docker-compose down || true

# Update docker-compose with new image
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  app:
    image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
    ports:
      - "3000:3000"
    environment:
      DB_HOST: \${DB_HOST}
      DB_USER: \${DB_USER}
      DB_PASSWORD: \${DB_PASSWORD}
      DB_NAME: \${DB_NAME}
      SESSION_SECRET: \${SESSION_SECRET}
      NODE_ENV: production
    restart: unless-stopped
EOF

# Start new container
docker-compose up -d

echo "Deployment complete!"
echo "Checking health..."
sleep 5
curl -f http://localhost:3000/api/health || echo "Health check failed!"
