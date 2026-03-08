#!/bin/bash
# setup-ssl.sh - Set up Let's Encrypt SSL certificate
# Usage: ./setup-ssl.sh <domain> <email>

set -e

DOMAIN=${1:-"qa.rahoi.dev"}
EMAIL=${2:-"admin@rahoi.dev"}

echo "🔐 Setting up SSL for: $DOMAIN"

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo yum install -y certbot
fi

# Stop the app temporarily to free port 80
echo "Stopping application temporarily..."
sudo docker stop color-app || true

# Obtain certificate
echo "Obtaining SSL certificate..."
sudo certbot certonly \
  --standalone \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  -d $DOMAIN

# Restart app
echo "Restarting application..."
sudo docker start color-app

# Create nginx config for SSL termination
echo "Setting up nginx for SSL termination..."
cat > /tmp/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server localhost:3000;
    }

    # HTTP redirect to HTTPS
    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name DOMAIN_PLACEHOLDER;

        ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;

        # SSL settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOF

# Replace domain placeholder
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /tmp/nginx.conf

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    sudo yum install -y nginx
fi

# Copy nginx config
sudo cp /tmp/nginx.conf /etc/nginx/nginx.conf

# Start nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

echo ""
echo "✅ SSL setup complete!"
echo ""
echo "🌐 Your site is now available at:"
echo "   https://$DOMAIN"
echo ""
echo "📝 Certificate will auto-renew via certbot timer"
echo "   Check renewal with: sudo certbot renew --dry-run"
