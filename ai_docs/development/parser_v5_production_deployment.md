# TrackerDelivery Parser v5.0 Production Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying TrackerDelivery Parser System v5.0 to production environments. The v5.0 system is specifically optimized for production server performance, with extended timeouts, performance optimizations, and robust error handling for slow network conditions.

## Prerequisites

### System Requirements

**Minimum Hardware:**
- **CPU**: 2 cores, 2.0 GHz
- **RAM**: 4 GB (2 GB minimum for parser processes)
- **Storage**: 10 GB free space
- **Network**: Stable internet connection with < 5s latency to target platforms

**Recommended Hardware:**
- **CPU**: 4 cores, 2.5 GHz
- **RAM**: 8 GB
- **Storage**: 20 GB SSD
- **Network**: High-speed connection with load balancing

### Software Dependencies

**Operating System:**
- Ubuntu 20.04 LTS or newer
- CentOS 8 or newer
- Amazon Linux 2
- Any Linux distribution with systemd

**Required Packages:**
```bash
# Base system packages
sudo apt-get update
sudo apt-get install -y curl wget gnupg2 software-properties-common

# Ruby environment
sudo apt-get install -y ruby ruby-dev build-essential zlib1g-dev

# Database and utilities
sudo apt-get install -y sqlite3 libsqlite3-dev git
```

### Browser and WebDriver Setup

**Chrome Installation:**
```bash
# Add Google Chrome repository
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

# Install Chrome
sudo apt-get update
sudo apt-get install -y google-chrome-stable

# Verify installation
google-chrome --version
```

**ChromeDriver Installation:**
```bash
# Download and install ChromeDriver
CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1)
wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROME_VERSION}/chromedriver_linux64.zip"
sudo unzip /tmp/chromedriver.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver

# Verify installation
chromedriver --version
```

**Alternative: Chromium Setup (for resource-constrained environments):**
```bash
# Install Chromium
sudo apt-get install -y chromium-browser chromium-chromedriver

# Set environment variables for Chromium
export CHROME_BIN="/usr/bin/chromium-browser"
export CHROMEDRIVER_PATH="/usr/bin/chromedriver"
```

## Environment Configuration

### Production Environment Variables

Create `/etc/environment` or add to your deployment configuration:

```bash
# Browser Configuration
CHROME_BIN="/usr/bin/google-chrome"
CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"

# Parser Performance Tuning
PARSER_TIMEOUT=60
GRAB_PARSER_TIMEOUT=20
GOJEK_PARSER_TIMEOUT=60

# Circuit Breaker Configuration
CIRCUIT_BREAKER_THRESHOLD=5
CIRCUIT_BREAKER_RESET_TIME=30

# Chrome Performance Flags
CHROME_DISABLE_IMAGES=true
CHROME_DISABLE_NOTIFICATIONS=true
CHROME_AGGRESSIVE_CACHE_DISCARD=true

# Rails Environment
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true

# Database
DATABASE_URL="sqlite3:db/production.sqlite3"

# Security
SECRET_KEY_BASE="your-secret-key-base-here"
```

### Chrome Headless Configuration

Create `/etc/chrome-flags.conf`:
```
# Performance optimizations for production
--no-sandbox
--disable-dev-shm-usage
--disable-gpu
--disable-software-rasterizer
--disable-background-timer-throttling
--disable-backgrounding-occluded-windows
--disable-renderer-backgrounding
--disable-features=TranslateUI
--disable-ipc-flooding-protection
--disable-images
--disable-notifications
--aggressive-cache-discard
--memory-pressure-off
--max_old_space_size=4096
```

## Application Deployment

### Code Deployment with Kamal

**1. Kamal Configuration** (`config/deploy.yml`):
```yaml
service: tracker-delivery
image: tracker-delivery
servers:
  - your-production-server.com

registry:
  username: your-docker-username
  password:
    - DOCKER_PASSWORD

env:
  clear:
    RAILS_ENV: production
  secret:
    - SECRET_KEY_BASE
    - CHROME_BIN
    - CHROMEDRIVER_PATH

volumes:
  - /var/lib/tracker-delivery:/app/db

healthcheck:
  path: /health
  port: 3000
  max_attempts: 7
  interval: 20s
```

**2. Deploy Application:**
```bash
# Initial deployment
kamal deploy

# Subsequent deployments
kamal deploy --skip-push  # if image already built
```

### Manual Deployment

**1. Clone and Setup:**
```bash
# Clone repository
git clone https://github.com/your-org/TrackerDelivery.git
cd TrackerDelivery

# Install dependencies
bundle install --deployment --without development test

# Setup database
RAILS_ENV=production bundle exec rails db:create db:migrate

# Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# Create log directory
mkdir -p log
chmod 755 log
```

**2. Systemd Service Configuration** (`/etc/systemd/system/tracker-delivery.service`):
```ini
[Unit]
Description=TrackerDelivery Parser Service
After=network.target
Requires=network.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/var/www/tracker-delivery
Environment=RAILS_ENV=production
Environment=CHROME_BIN=/usr/bin/google-chrome
Environment=CHROMEDRIVER_PATH=/usr/local/bin/chromedriver
ExecStart=/usr/local/bin/bundle exec rails server -p 3000 -e production
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tracker-delivery

# Resource limits
LimitNOFILE=65536
MemoryMax=2G
CPUQuota=200%

[Install]
WantedBy=multi-user.target
```

**3. Start Service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable tracker-delivery
sudo systemctl start tracker-delivery
sudo systemctl status tracker-delivery
```

## Performance Optimization

### Memory Management

**Chrome Memory Optimization:**
```bash
# Add to Chrome flags
--memory-pressure-off
--max_old_space_size=4096
--aggressive-cache-discard
--disable-background-timer-throttling
```

**System-level Optimization:**
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Memory overcommit settings
echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
sysctl -p
```

### Network Optimization

**TCP Optimization:**
```bash
# Add to /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# Apply settings
sysctl -p
```

### Parser-Specific Tuning

**Grab Parser Configuration:**
```ruby
# config/initializers/parser_config.rb
Rails.application.configure do
  config.grab_parser_timeout = ENV.fetch('GRAB_PARSER_TIMEOUT', 20).to_i
  config.grab_parser_retry_delays = [2, 4, 8]
  config.grab_parser_max_retries = 3
end
```

**GoJek Parser Configuration:**
```ruby
# Optimized for production servers
Rails.application.configure do
  config.gojek_parser_timeout = ENV.fetch('GOJEK_PARSER_TIMEOUT', 60).to_i
  config.gojek_page_load_timeout = 45
  config.gojek_script_timeout = 30
  config.gojek_wait_reduction = true  # Enables reduced wait times
end
```

## Monitoring and Alerting

### Application Monitoring

**Health Check Endpoint** (`config/routes.rb`):
```ruby
Rails.application.routes.draw do
  get '/health', to: 'health#check'
  get '/health/parsers', to: 'health#parsers'
end
```

**Health Controller:**
```ruby
class HealthController < ApplicationController
  def check
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: '5.0',
      circuit_breaker: {
        grab: circuit_breaker_status(GrabParserService),
        gojek: circuit_breaker_status(GojekParserService)
      }
    }
  end

  def parsers
    results = {
      grab: test_parser(GrabParserService, 'https://food.grab.com/test'),
      gojek: test_parser(GojekParserService, 'https://gofood.co.id/test')
    }
    
    status = results.values.all? { |r| r[:status] == 'ok' } ? 200 : 503
    render json: results, status: status
  end

  private

  def circuit_breaker_status(parser_class)
    {
      failures: parser_class.circuit_breaker_failures || 0,
      open: parser_class.circuit_breaker_opened_at ? 
            (Time.current - parser_class.circuit_breaker_opened_at < 30) : false
    }
  end

  def test_parser(parser_class, test_url)
    start_time = Time.current
    result = parser_class.new.parse(test_url)
    duration = Time.current - start_time

    {
      status: result ? 'ok' : 'error',
      duration: duration.round(2),
      timestamp: Time.current.iso8601
    }
  rescue => e
    {
      status: 'error',
      error: e.class.name,
      message: e.message,
      timestamp: Time.current.iso8601
    }
  end
end
```

### Log Management

**Structured Logging Configuration:**
```ruby
# config/environments/production.rb
Rails.application.configure do
  # Use JSON formatter for structured logs
  config.log_formatter = proc do |severity, datetime, progname, msg|
    {
      timestamp: datetime.iso8601,
      level: severity,
      message: msg,
      service: 'tracker-delivery',
      version: '5.0'
    }.to_json + "\n"
  end

  # Log to stdout for container environments
  config.logger = ActiveSupport::Logger.new(STDOUT) if ENV['RAILS_LOG_TO_STDOUT']
  
  # Set log level
  config.log_level = :info
end
```

**Log Rotation:**
```bash
# /etc/logrotate.d/tracker-delivery
/var/www/tracker-delivery/log/*.log {
  daily
  missingok
  rotate 30
  compress
  delaycompress
  notifempty
  create 0644 deploy deploy
  postrotate
    systemctl reload tracker-delivery
  endscript
}
```

### Metrics Collection

**Parser Metrics Script** (`bin/collect_metrics`):
```bash
#!/bin/bash
# Parser performance metrics collector

LOGFILE="/var/log/tracker-delivery/metrics.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Test both parsers
GRAB_RESULT=$(curl -s http://localhost:3000/health/parsers | jq '.grab')
GOJEK_RESULT=$(curl -s http://localhost:3000/health/parsers | jq '.gojek')

# Extract metrics
GRAB_STATUS=$(echo $GRAB_RESULT | jq -r '.status')
GRAB_DURATION=$(echo $GRAB_RESULT | jq -r '.duration')
GOJEK_STATUS=$(echo $GOJEK_RESULT | jq -r '.status')
GOJEK_DURATION=$(echo $GOJEK_RESULT | jq -r '.duration')

# Log metrics
echo "$DATE,grab,$GRAB_STATUS,$GRAB_DURATION" >> $LOGFILE
echo "$DATE,gojek,$GOJEK_STATUS,$GOJEK_DURATION" >> $LOGFILE

# Check for circuit breaker alerts
CIRCUIT_STATUS=$(curl -s http://localhost:3000/health | jq '.circuit_breaker')
if echo $CIRCUIT_STATUS | jq -e '.grab.open == true or .gojek.open == true' > /dev/null; then
  echo "$DATE: ALERT - Circuit breaker activated" >> $LOGFILE
  # Send alert notification here
fi
```

**Add to Crontab:**
```bash
# Monitor every 5 minutes
*/5 * * * * /var/www/tracker-delivery/bin/collect_metrics
```

## Security Configuration

### Firewall Setup

```bash
# UFW configuration
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 3000/tcp  # Application port
sudo ufw allow 80/tcp    # HTTP (if using reverse proxy)
sudo ufw allow 443/tcp   # HTTPS (if using reverse proxy)
sudo ufw enable
```

### SSL/TLS with Nginx Reverse Proxy

**Nginx Configuration** (`/etc/nginx/sites-available/tracker-delivery`):
```nginx
upstream tracker_delivery {
  server 127.0.0.1:3000 fail_timeout=0;
}

server {
  listen 80;
  server_name your-domain.com;
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name your-domain.com;

  ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

  # SSL configuration
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
  ssl_prefer_server_ciphers off;
  ssl_session_cache shared:SSL:10m;

  location / {
    proxy_pass http://tracker_delivery;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Increase timeouts for parser operations
    proxy_read_timeout 120s;
    proxy_connect_timeout 10s;
  }

  # Health check endpoint
  location /health {
    proxy_pass http://tracker_delivery;
    access_log off;
  }
}
```

## Troubleshooting

### Common Deployment Issues

**1. ChromeDriver Version Mismatch:**
```bash
# Check versions
google-chrome --version
chromedriver --version

# Fix: Update ChromeDriver
CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1)
wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROME_VERSION}/chromedriver_linux64.zip"
sudo unzip /tmp/chromedriver.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
```

**2. Memory Issues:**
```bash
# Check memory usage
free -h
ps aux | grep chrome | head -10

# Fix: Restart service and clear Chrome cache
sudo systemctl restart tracker-delivery
rm -rf /tmp/.com.google.Chrome.*
```

**3. Permission Issues:**
```bash
# Fix Chrome permissions
sudo chown -R deploy:deploy /var/www/tracker-delivery
sudo chmod +x /usr/bin/google-chrome
sudo chmod +x /usr/local/bin/chromedriver
```

### Performance Diagnostics

**Parser Performance Test:**
```bash
# Test individual parsers
bin/rails runner "puts 'Testing Grab...'; start = Time.current; result = GrabParserService.new.parse('https://food.grab.com/test'); puts \"Duration: #{Time.current - start}s, Success: #{!result.nil?}\""

bin/rails runner "puts 'Testing GoJek...'; start = Time.current; result = GojekParserService.new.parse('https://gofood.co.id/test'); puts \"Duration: #{Time.current - start}s, Success: #{!result.nil?}\""
```

**Circuit Breaker Status:**
```bash
bin/rails runner "puts \"Grab CB: #{GrabParserService.circuit_breaker_failures}/5 failures\"; puts \"GoJek CB: #{GojekParserService.circuit_breaker_failures}/5 failures\""
```

## Maintenance Procedures

### Regular Maintenance Tasks

**Daily:**
- Check application logs for errors
- Monitor memory usage
- Verify parser success rates

**Weekly:**
- Update ChromeDriver if needed
- Clean temporary files
- Review performance metrics

**Monthly:**
- Update system packages
- Rotate and archive logs
- Performance optimization review

### Backup Procedures

**Database Backup:**
```bash
#!/bin/bash
# backup_database.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/tracker-delivery"
mkdir -p $BACKUP_DIR

# Backup SQLite database
cp /var/www/tracker-delivery/db/production.sqlite3 $BACKUP_DIR/database_$DATE.sqlite3

# Compress older backups
find $BACKUP_DIR -name "*.sqlite3" -mtime +7 -exec gzip {} \;

# Remove backups older than 30 days
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
```

**Configuration Backup:**
```bash
# backup_config.sh
tar -czf /var/backups/tracker-delivery/config_$(date +%Y%m%d).tar.gz \
  /etc/systemd/system/tracker-delivery.service \
  /etc/nginx/sites-available/tracker-delivery \
  /var/www/tracker-delivery/config/
```

## Scaling Considerations

### Horizontal Scaling

**Load Balancer Configuration:**
```nginx
upstream tracker_delivery_cluster {
  server 10.0.1.10:3000 weight=1 max_fails=3 fail_timeout=30s;
  server 10.0.1.11:3000 weight=1 max_fails=3 fail_timeout=30s;
  server 10.0.1.12:3000 weight=1 max_fails=3 fail_timeout=30s;
}
```

**Shared Circuit Breaker State:**
Consider using Redis for shared circuit breaker state across instances:
```ruby
# config/initializers/circuit_breaker.rb
if Rails.env.production? && ENV['REDIS_URL']
  require 'redis'
  CIRCUIT_BREAKER_REDIS = Redis.new(url: ENV['REDIS_URL'])
end
```

### Resource Monitoring

**Server Monitoring Script:**
```bash
#!/bin/bash
# monitor_resources.sh

# CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# Memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')

# Disk usage
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)

# Chrome processes
CHROME_PROCS=$(ps aux | grep -c "[c]hrome")

echo "$(date): CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%, Disk: ${DISK_USAGE}%, Chrome Processes: ${CHROME_PROCS}"

# Alert if thresholds exceeded
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
  echo "ALERT: High CPU usage: ${CPU_USAGE}%"
fi

if (( $(echo "$MEM_USAGE > 85" | bc -l) )); then
  echo "ALERT: High memory usage: ${MEM_USAGE}%"
fi

if [ "$CHROME_PROCS" -gt 10 ]; then
  echo "ALERT: Too many Chrome processes: ${CHROME_PROCS}"
fi
```

This production deployment guide ensures reliable, scalable, and maintainable deployment of TrackerDelivery Parser System v5.0 in production environments.