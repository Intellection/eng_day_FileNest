# FileNest Production Deployment Guide 🚀

This guide will help you deploy FileNest to production safely and securely.

## 📋 Prerequisites

### System Requirements
- **Ruby**: 3.3.5 or higher
- **Rails**: 8.0.2
- **Database**: PostgreSQL 12+ (recommended for production)
- **Storage**: Local filesystem or cloud storage (S3, GCS, Azure)
- **Web Server**: Nginx or Apache (recommended)
- **Process Manager**: systemd, PM2, or similar
- **SSL Certificate**: Let's Encrypt or commercial certificate

### Minimum Server Specifications
- **RAM**: 2GB minimum, 4GB recommended
- **CPU**: 2 cores minimum
- **Storage**: 20GB minimum, SSD recommended
- **Network**: Stable internet connection with adequate bandwidth

## 🔧 Production Setup

### 1. Server Preparation

#### Ubuntu/Debian
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl git build-essential libssl-dev libreadline-dev \
  zlib1g-dev libpq-dev postgresql postgresql-contrib nginx

# Install Ruby (using rbenv)
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.3.5
rbenv install 3.3.5
rbenv global 3.3.5
gem install bundler
```

#### CentOS/RHEL
```bash
# Update system
sudo dnf update -y

# Install dependencies
sudo dnf install -y curl git gcc make openssl-devel readline-devel \
  zlib-devel postgresql-devel postgresql-server nginx

# Configure PostgreSQL
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 2. Database Setup

#### PostgreSQL Configuration
```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE filenest_production;
CREATE USER filenest_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE filenest_production TO filenest_user;
ALTER USER filenest_user CREATEDB;
\q
```

#### Database Security
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/14/main/postgresql.conf

# Recommended settings:
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
```

### 3. Application Deployment

#### Clone and Setup
```bash
# Create application directory
sudo mkdir -p /var/www/filenest
sudo chown $USER:$USER /var/www/filenest

# Clone repository
cd /var/www/filenest
git clone https://github.com/yourusername/filenest.git .

# Install gems
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install
```

#### Environment Configuration
```bash
# Create production environment file
nano .env.production
```

Add the following environment variables:
```bash
# Database
DATABASE_URL=postgresql://filenest_user:your_secure_password@localhost/filenest_production

# Security
SECRET_KEY_BASE=your_very_long_random_secret_key_here
RAILS_ENV=production

# File Storage (choose one)
# Local storage (default)
STORAGE_SERVICE=local
STORAGE_ROOT=/var/www/filenest/storage

# AWS S3 (optional)
# STORAGE_SERVICE=s3
# AWS_ACCESS_KEY_ID=your_aws_access_key
# AWS_SECRET_ACCESS_KEY=your_aws_secret_key
# AWS_REGION=us-east-1
# AWS_S3_BUCKET=your-filenest-bucket

# Application Settings
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
RAILS_LOG_LEVEL=info

# Security Headers
RAILS_FORCE_SSL=true
```

#### Generate Secret Key
```bash
# Generate a secure secret key
bundle exec rails secret
```

#### Database Migration
```bash
# Set environment
export RAILS_ENV=production

# Load environment variables
source .env.production

# Create and migrate database
bundle exec rails db:create
bundle exec rails db:migrate

# Precompile assets (if serving assets through Rails)
bundle exec rails assets:precompile
```

### 4. Web Server Configuration

#### Nginx Configuration
```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/filenest
```

```nginx
upstream filenest {
    server unix:///var/www/filenest/tmp/sockets/puma.sock;
}

server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /var/www/filenest/public;
    
    # File upload size limit
    client_max_body_size 2M;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Static files
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Rails application
    location / {
        try_files $uri @filenest;
    }

    location @filenest {
        proxy_pass http://filenest;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://filenest;
        access_log off;
    }
}
```

#### Enable Nginx Site
```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/filenest /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### 5. SSL Certificate Setup

#### Using Let's Encrypt
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 6. Process Management

#### Puma Configuration
```bash
# Create Puma configuration
nano config/puma.rb
```

```ruby
# Puma configuration for production
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  ActiveRecord::Base.establish_connection
end

# Production specific settings
if ENV['RAILS_ENV'] == 'production'
  bind "unix:///var/www/filenest/tmp/sockets/puma.sock"
  pidfile "/var/www/filenest/tmp/pids/puma.pid"
  state_path "/var/www/filenest/tmp/pids/puma.state"
  
  # Logging
  stdout_redirect "/var/www/filenest/log/puma.stdout.log", 
                  "/var/www/filenest/log/puma.stderr.log", true
end
```

#### Systemd Service
```bash
# Create systemd service
sudo nano /etc/systemd/system/filenest.service
```

```ini
[Unit]
Description=FileNest Puma Server
After=network.target

[Service]
Type=notify
User=deploy
WorkingDirectory=/var/www/filenest
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/filenest/.env.production
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -SIGUSR1 $MAINPID
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
```

#### Start Services
```bash
# Create necessary directories
mkdir -p /var/www/filenest/tmp/sockets
mkdir -p /var/www/filenest/tmp/pids
mkdir -p /var/www/filenest/log

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable filenest
sudo systemctl start filenest

# Check status
sudo systemctl status filenest
```

## 🔒 Security Considerations

### 1. Firewall Configuration
```bash
# UFW (Ubuntu)
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 2. File Permissions
```bash
# Set proper ownership
sudo chown -R deploy:deploy /var/www/filenest

# Set secure permissions
chmod 755 /var/www/filenest
chmod -R 644 /var/www/filenest/*
chmod 755 /var/www/filenest/bin/*
chmod 600 /var/www/filenest/.env.production
```

### 3. Database Security
```bash
# Restrict PostgreSQL access
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Use md5 authentication for local connections
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
```

### 4. Application Security
- Use strong, unique passwords for all accounts
- Regularly update gems and dependencies
- Monitor logs for suspicious activity
- Implement rate limiting if needed
- Use HTTPS everywhere
- Validate all file uploads
- Sanitize user input

## 📊 Monitoring and Logging

### 1. Log Configuration
```bash
# Rails logs
tail -f /var/www/filenest/log/production.log

# Puma logs
tail -f /var/www/filenest/log/puma.stdout.log

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### 2. Log Rotation
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/filenest
```

```
/var/www/filenest/log/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 deploy deploy
    postrotate
        systemctl reload filenest
    endscript
}
```

### 3. Health Monitoring
```bash
# Create monitoring script
nano /var/www/filenest/scripts/health_check.sh
```

```bash
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [ $response != "200" ]; then
    echo "Health check failed with status: $response"
    # Add notification logic (email, Slack, etc.)
    exit 1
fi
```

## 🚀 Deployment Automation

### 1. Deployment Script
```bash
# Create deployment script
nano /var/www/filenest/scripts/deploy.sh
```

```bash
#!/bin/bash
set -e

echo "Starting deployment..."

# Pull latest code
git pull origin main

# Install/update gems
bundle install --deployment --without development test

# Migrate database
RAILS_ENV=production bundle exec rails db:migrate

# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# Restart application
sudo systemctl restart filenest

# Health check
sleep 10
./scripts/health_check.sh

echo "Deployment completed successfully!"
```

### 2. Zero-Downtime Deployment
For zero-downtime deployments, consider using:
- **Capistrano**: Ruby deployment tool
- **Docker**: Containerized deployments
- **Blue-Green Deployment**: Two identical production environments

## 📈 Performance Optimization

### 1. Database Optimization
```sql
-- Add database indexes for better performance
CREATE INDEX CONCURRENTLY idx_user_files_user_id ON user_files(user_id);
CREATE INDEX CONCURRENTLY idx_user_files_uploaded_at ON user_files(uploaded_at);
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

### 2. Caching
Consider implementing:
- **Redis**: For session storage and caching
- **CDN**: For static file delivery
- **Application-level caching**: For database queries

### 3. Background Jobs
For file processing tasks:
```ruby
# Add to Gemfile
gem 'sidekiq'
gem 'redis'

# Configure background jobs for file processing
```

## 🔄 Backup Strategy

### 1. Database Backups
```bash
# Create backup script
nano /var/www/filenest/scripts/backup_db.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/filenest"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
pg_dump filenest_production | gzip > $BACKUP_DIR/db_backup_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +30 -delete
```

### 2. File Storage Backups
```bash
# For local storage
rsync -av /var/www/filenest/storage/ /backup/filenest_files/

# For S3 storage, backups are handled by AWS
# Consider enabling versioning and cross-region replication
```

### 3. Automated Backups
```bash
# Add to crontab
0 2 * * * /var/www/filenest/scripts/backup_db.sh
0 3 * * * rsync -av /var/www/filenest/storage/ /backup/filenest_files/
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Application Won't Start
```bash
# Check logs
sudo journalctl -u filenest -f

# Check database connection
RAILS_ENV=production bundle exec rails console
> ActiveRecord::Base.connection.execute('SELECT 1')
```

#### 2. File Upload Issues
```bash
# Check permissions
ls -la /var/www/filenest/storage/

# Check disk space
df -h

# Check Nginx upload size limit
grep client_max_body_size /etc/nginx/sites-available/filenest
```

#### 3. SSL Certificate Issues
```bash
# Test certificate
openssl s_client -connect your-domain.com:443

# Renew certificate
sudo certbot renew --dry-run
```

#### 4. Performance Issues
```bash
# Monitor system resources
htop
iotop

# Check database performance
sudo -u postgres psql filenest_production
> EXPLAIN ANALYZE SELECT * FROM user_files WHERE user_id = 1;
```

## 📞 Support and Maintenance

### Regular Maintenance Tasks
- **Weekly**: Review logs and system performance
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and test backup/restore procedures
- **Annually**: Security audit and penetration testing

### Getting Help
- Check the application logs first
- Review this documentation
- Check GitHub issues
- Contact the development team

---

**Remember**: Always test deployments in a staging environment before deploying to production!

For additional support or questions, please refer to the main README.md file or create an issue in the project repository.