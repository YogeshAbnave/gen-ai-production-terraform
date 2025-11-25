#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Python 3.11
apt-get install -y python3 python3-pip python3-venv

# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install NGINX
apt-get install -y nginx

# Create application directories
mkdir -p /var/www/html
mkdir -p /var/www/backend
mkdir -p /var/log/fastapi

# Set permissions
chown -R ubuntu:ubuntu /var/www
chown -R ubuntu:ubuntu /var/log/fastapi

# Create systemd service for FastAPI
cat > /etc/systemd/system/fastapi.service <<'EOF'
[Unit]
Description=FastAPI CRUD Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/backend
Environment="DYNAMODB_TABLE=${dynamodb_table}"
Environment="AWS_REGION=${aws_region}"
Environment="S3_BUCKET_NAME=${s3_bucket_name}"
Environment="CLOUDFRONT_DOMAIN=${cloudfront_domain}"
ExecStart=/var/www/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure NGINX
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    # Frontend
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Test NGINX configuration
nginx -t

# Restart NGINX
systemctl restart nginx
systemctl enable nginx

# Create placeholder index.html
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CRUD App - Deploying</title>
</head>
<body>
    <h1>Application is being deployed...</h1>
    <p>Please wait for the deployment to complete.</p>
</body>
</html>
EOF

echo "User data script completed successfully"
