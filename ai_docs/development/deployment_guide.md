# TrackerDelivery Deployment Guide v3.0

## 🚀 Deployment Overview

TrackerDelivery uses **Kamal** for modern container-based deployment, providing zero-downtime deployments with built-in health checks and rollback capabilities. This guide covers the complete deployment process from development to production.

## 🏗️ Deployment Architecture

### Infrastructure Stack
```
Production Environment:
├── 🌐 Load Balancer (Traefik)
├── 🐳 Application Container (Rails + Puma)
├── 📊 Database (PostgreSQL)  
├── 🔄 Background Jobs (Solid Queue)
├── 💾 Caching (Solid Cache)
├── 📡 WebSockets (Solid Cable)
└── 📈 Monitoring (Health Checks)
```

### Server Requirements
- **CPU**: 2 vCPU minimum (4 vCPU recommended)
- **RAM**: 4GB minimum (8GB recommended)  
- **Storage**: 50GB SSD minimum
- **Network**: 100Mbps bandwidth
- **OS**: Ubuntu 22.04 LTS (recommended)

## ⚙️ Kamal Configuration

### Main Configuration (`config/deploy.yml`)
```yaml
# config/deploy.yml
service: trackerdelivery
image: trackerdelivery

servers:
  web:
    hosts:
      - 139.162.XX.XX
    options:
      add-host: host.docker.internal:host-gateway
    labels:
      traefik.http.routers.trackerdelivery.entrypoints: websecure
      traefik.http.routers.trackerdelivery.rule: Host(`aidelivery.tech`)
      traefik.http.routers.trackerdelivery.tls.certresolver: letsencrypt
      traefik.http.services.trackerdelivery.loadbalancer.server.port: 3000

registry:
  server: ghcr.io
  username:
    - GITHUB_USER
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - POSTGRES_PASSWORD
  clear:
    - RAILS_ENV=production
    - RAILS_LOG_TO_STDOUT=true

traefik:
  options:
    publish:
      - "443:443"
    volume:
      - "/letsencrypt/acme.json:/letsencrypt/acme.json"
  args:
    entryPoints.web.address: ":80"
    entryPoints.websecure.address: ":443"
    certificatesResolvers.letsencrypt.acme.tlsChallenge: true
    certificatesResolvers.letsencrypt.acme.email: "admin@aidelivery.tech"
    certificatesResolvers.letsencrypt.acme.storage: "/letsencrypt/acme.json"

accessories:
  postgres:
    image: postgres:15
    host: 139.162.XX.XX
    env:
      secret:
        - POSTGRES_PASSWORD
      clear:
        - POSTGRES_USER=trackerdelivery
        - POSTGRES_DB=trackerdelivery_production
    directories:
      - data:/var/lib/postgresql/data
    
healthcheck:
  path: /up
  port: 3000
  max_attempts: 10
  interval: 5s
```

### Secrets Configuration (`.kamal/secrets`)
```bash
# .kamal/secrets
KAMAL_REGISTRY_PASSWORD=ghp_xxx...
RAILS_MASTER_KEY=$(cat config/master.key)
DATABASE_URL=postgresql://trackerdelivery:password@postgres:5432/trackerdelivery_production
POSTGRES_PASSWORD=secure_database_password_here
```

## 🔧 Environment Setup

### Production Environment Variables
```bash
# Production environment configuration
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
SECRET_KEY_BASE=generated_secret_key
DATABASE_URL=postgresql://user:pass@host:5432/database
REDIS_URL=redis://localhost:6379/0
```

### Required Secrets
- `RAILS_MASTER_KEY`: Rails credentials encryption key
- `DATABASE_URL`: PostgreSQL connection string
- `POSTGRES_PASSWORD`: Database user password
- `KAMAL_REGISTRY_PASSWORD`: Container registry access token

## 📦 Docker Configuration

### Dockerfile
```dockerfile
# Dockerfile
ARG RUBY_VERSION=3.3.5
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /rails

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Start server
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
```

### .dockerignore
```
.git
.github
.kamal
node_modules
tmp
log
.env*
.DS_Store
coverage
```

## 🚀 Deployment Commands

### Initial Setup
```bash
# Setup server and deploy for first time
kamal setup

# Check deployment status
kamal details

# View application logs
kamal logs
```

### Regular Deployments
```bash
# Deploy latest changes
kamal deploy

# Deploy specific version
kamal deploy --version=v3.1.0

# Rollback to previous version
kamal rollback [VERSION]
```

### Maintenance Commands
```bash
# SSH into application server
kamal app exec "bash"

# Run database migrations
kamal app exec "bin/rails db:migrate"

# Check server status
kamal server exec "docker ps"

# View detailed logs
kamal logs --grep="ERROR"
```

## 🔍 Health Checks & Monitoring

### Application Health Check
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      database: check_database,
      redis: check_redis,
      timestamp: Time.current
    }
  end
  
  private
  
  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    'healthy'
  rescue => e
    'unhealthy'
  end
  
  def check_redis
    # Redis health check if using Redis
    'healthy'
  rescue => e
    'unhealthy'
  end
end
```

### Monitoring Endpoints
- **Health Check**: `GET /up` - Application health status
- **Database Check**: Included in health endpoint
- **Background Jobs**: Solid Queue monitoring
- **Error Tracking**: Rails error handling

## 📊 Database Management

### PostgreSQL Setup
```sql
-- Create production database and user
CREATE USER trackerdelivery WITH PASSWORD 'secure_password';
CREATE DATABASE trackerdelivery_production OWNER trackerdelivery;
GRANT ALL PRIVILEGES ON DATABASE trackerdelivery_production TO trackerdelivery;
```

### Migration Commands
```bash
# Run pending migrations
kamal app exec "bin/rails db:migrate"

# Seed production data
kamal app exec "bin/rails db:seed"

# Create database backup
kamal server exec "pg_dump trackerdelivery_production > backup_$(date +%Y%m%d).sql"
```

## 🔒 SSL/TLS Configuration

### Let's Encrypt Setup
```bash
# Initialize SSL certificate storage
kamal server exec "mkdir -p /letsencrypt && touch /letsencrypt/acme.json && chmod 600 /letsencrypt/acme.json"

# Deploy with SSL configuration
kamal deploy
```

### SSL Verification
```bash
# Check SSL certificate
openssl s_client -connect aidelivery.tech:443 -servername aidelivery.tech

# Verify certificate expiration
echo | openssl s_client -connect aidelivery.tech:443 2>/dev/null | openssl x509 -noout -dates
```

## 🚨 Deployment Troubleshooting

### Common Issues

#### Container Build Failures
```bash
# Check build logs
kamal build logs

# Rebuild container
kamal build --no-push

# Force rebuild
kamal build --clear
```

#### Database Connection Issues
```bash
# Check database accessibility
kamal accessory logs postgres

# Test database connection
kamal app exec "bin/rails db:migrate:status"

# Reset database connection
kamal app exec "bin/rails db:reset"
```

#### SSL Certificate Issues
```bash
# Check Traefik logs
kamal accessory logs traefik

# Restart Traefik
kamal accessory restart traefik

# Manual certificate verification
curl -I https://aidelivery.tech
```

### Debugging Commands
```bash
# Application container logs
kamal logs --tail=100

# Server system logs
kamal server exec "journalctl -u docker --no-pager --lines=50"

# Container inspection
kamal app exec "ps aux"
kamal app exec "df -h"
kamal app exec "free -m"
```

## 📈 Performance Optimization

### Application Performance
```ruby
# config/environments/production.rb
Rails.application.configure do
  # Enable caching
  config.cache_classes = true
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000'
  }
  
  # Logging optimization
  config.log_level = :info
  config.log_tags = [:request_id]
end
```

### Database Performance
```ruby
# config/database.yml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 20) %>
  timeout: 5000
  url: <%= ENV['DATABASE_URL'] %>
  prepared_statements: true
  advisory_locks: true
```

## 🔄 Backup Strategy

### Database Backups
```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
kamal server exec "pg_dump trackerdelivery_production | gzip > /backups/db_backup_$DATE.sql.gz"

# Automated backup via cron
0 2 * * * /path/to/backup_script.sh
```

### Application Backups
```bash
# Backup uploaded files (if any)
kamal server exec "tar -czf /backups/uploads_$(date +%Y%m%d).tar.gz /rails/storage"

# Configuration backup
tar -czf config_backup_$(date +%Y%m%d).tar.gz .kamal/ config/
```

## 🌊 Blue-Green Deployments

### Zero-Downtime Strategy
```bash
# Kamal handles blue-green deployments automatically
kamal deploy

# Process:
# 1. Build new container image
# 2. Start new container alongside old one
# 3. Health check new container
# 4. Switch traffic to new container
# 5. Stop old container
```

### Rollback Procedure
```bash
# List available versions
kamal app details

# Rollback to specific version
kamal rollback 20240913_143022

# Emergency rollback to previous
kamal rollback
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing locally
- [ ] Database migrations tested
- [ ] Environment variables configured
- [ ] SSL certificates valid
- [ ] Backup strategy in place

### Deployment
- [ ] Build container successfully
- [ ] Database migrations applied
- [ ] Health checks passing
- [ ] SSL/HTTPS working
- [ ] Application accessible

### Post-Deployment
- [ ] Monitor application logs
- [ ] Verify key functionality
- [ ] Check error rates
- [ ] Performance monitoring
- [ ] User acceptance validation

## 🎯 Scaling Considerations

### Horizontal Scaling
```yaml
# Multiple servers configuration
servers:
  web:
    hosts:
      - 139.162.XX.XX
      - 139.162.XX.XY  
    options:
      add-host: host.docker.internal:host-gateway
```

### Load Balancer Configuration
```yaml
# Traefik load balancing
traefik:
  args:
    api.dashboard: true
    api.insecure: true
    providers.docker: true
    providers.docker.exposedbydefault: false
```

---

This deployment guide ensures reliable, scalable, and secure deployment of TrackerDelivery from development through production environments using modern containerized infrastructure.