# TrackerDelivery Parser v5.0 Troubleshooting Guide

## Overview

This comprehensive troubleshooting guide covers common issues, diagnostic procedures, and solutions for TrackerDelivery Parser System v5.0. The guide is organized by symptom type with step-by-step resolution procedures.

## Quick Diagnostic Commands

### Health Check Commands
```bash
# Basic health check
curl http://localhost:3000/health

# Parser-specific health check
curl http://localhost:3000/health/parsers

# Circuit breaker status
bin/rails runner "puts 'Grab CB: ' + GrabParserService.circuit_breaker_failures.to_s; puts 'GoJek CB: ' + GojekParserService.circuit_breaker_failures.to_s"

# Manual parser test
bin/rails runner "puts GrabParserService.new.parse('https://food.grab.com/id/en/restaurant/test-url')"
```

### System Status Commands
```bash
# Check Chrome installation
google-chrome --version
which google-chrome

# Check ChromeDriver
chromedriver --version
which chromedriver

# Check running processes
ps aux | grep chrome
ps aux | grep rails

# Check memory usage
free -h
ps aux --sort=-%mem | head

# Check log files
tail -f log/production.log
journalctl -u tracker-delivery.service -f
```

## Common Issues and Solutions

### 1. Parser Returning Null Results

**Symptoms:**
```
Parser returns nil consistently
No error messages in logs
Health check shows "error" status
```

**Diagnostic Steps:**
```bash
# 1. Check if URL is accessible
curl -I "https://food.grab.com/id/en/restaurant/test-url"

# 2. Test parser manually with logging
bin/rails runner "
  puts 'Testing parser...'
  result = GrabParserService.new.parse('YOUR_TEST_URL')
  puts 'Result: ' + result.inspect
"

# 3. Check browser accessibility
google-chrome --headless --dump-dom "https://food.grab.com" | head -20
```

**Common Causes & Solutions:**

**A. Invalid or Expired URLs**
```ruby
# Check URL format in Rails console
bin/rails console
url = "your-test-url"
puts url.match?(/^https?:\/\//)
puts URI.parse(url) rescue "Invalid URL"
```

**B. Website Structure Changes**
```bash
# Compare page structure
bin/rails runner "
  require 'selenium-webdriver'
  driver = Selenium::WebDriver.for :chrome, options: Selenium::WebDriver::Chrome::Options.new(args: ['--headless'])
  driver.get('YOUR_URL')
  puts driver.page_source[0..1000]
  driver.quit
"
```

**C. Network Connectivity Issues**
```bash
# Test network connectivity
ping food.grab.com
ping gofood.co.id
nslookup food.grab.com
```

**Solutions:**
1. Update URL patterns if website structure changed
2. Check network configuration and firewall rules
3. Verify DNS resolution
4. Update parser selectors if needed

### 2. Circuit Breaker Activated

**Symptoms:**
```
Log message: "Circuit breaker is OPEN, skipping parse attempt"
Health check shows circuit breaker open
All parse attempts fail immediately
```

**Diagnostic Steps:**
```bash
# Check circuit breaker status
bin/rails runner "
  puts 'Grab Parser:'
  puts '  Failures: ' + GrabParserService.circuit_breaker_failures.to_s
  puts '  Opened at: ' + (GrabParserService.circuit_breaker_opened_at || 'Never').to_s
  puts '  Open?: ' + (Time.current - (GrabParserService.circuit_breaker_opened_at || Time.current) < 30).to_s
  
  puts 'GoJek Parser:'
  puts '  Failures: ' + GojekParserService.circuit_breaker_failures.to_s
  puts '  Opened at: ' + (GojekParserService.circuit_breaker_opened_at || 'Never').to_s
"
```

**Immediate Solutions:**

**A. Wait for Automatic Reset (30 seconds)**
```bash
# Monitor automatic reset
watch -n 5 'curl -s http://localhost:3000/health | jq .circuit_breaker'
```

**B. Manual Reset**
```bash
# Reset circuit breaker manually
bin/rails runner "
  GrabParserService.circuit_breaker_failures = 0
  GrabParserService.circuit_breaker_opened_at = nil
  GojekParserService.circuit_breaker_failures = 0
  GojekParserService.circuit_breaker_opened_at = nil
  puts 'Circuit breakers reset'
"
```

**C. Identify Root Cause**
```bash
# Check recent errors in logs
grep -A 5 -B 5 "RECOVERABLE ERROR\|NON-RECOVERABLE ERROR" log/production.log | tail -50

# Check system resources
free -h
df -h
ps aux --sort=-%mem | head -10
```

**Long-term Solutions:**
1. Investigate underlying cause of failures
2. Adjust circuit breaker thresholds if needed
3. Improve error handling in specific scenarios
4. Monitor system resources and optimize

### 3. Chrome/ChromeDriver Issues

**Symptoms:**
```
Selenium::WebDriver::Error::SessionNotCreatedError
Browser crashes or fails to start
ChromeDriver version mismatch errors
```

**Diagnostic Steps:**
```bash
# 1. Verify Chrome installation
google-chrome --version
which google-chrome
ls -la /usr/bin/google-chrome

# 2. Verify ChromeDriver installation
chromedriver --version
which chromedriver
ls -la /usr/local/bin/chromedriver

# 3. Test Chrome manually
google-chrome --headless --dump-dom "https://google.com" | head -10

# 4. Check Chrome processes
ps aux | grep chrome
lsof -i | grep chrome
```

**Common Solutions:**

**A. Version Mismatch**
```bash
# Check versions
CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1)
DRIVER_VERSION=$(chromedriver --version | awk '{print $2}' | cut -d. -f1)

echo "Chrome major version: $CHROME_VERSION"
echo "ChromeDriver major version: $DRIVER_VERSION"

# Update ChromeDriver if needed
wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROME_VERSION}/chromedriver_linux64.zip"
sudo unzip /tmp/chromedriver.zip -d /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
```

**B. Permission Issues**
```bash
# Fix Chrome permissions
sudo chown -R $(whoami):$(whoami) ~/.config/google-chrome
sudo chmod +x /usr/bin/google-chrome
sudo chmod +x /usr/local/bin/chromedriver

# Create Chrome data directory
mkdir -p ~/.config/google-chrome
chmod 755 ~/.config/google-chrome
```

**C. Resource Exhaustion**
```bash
# Kill stuck Chrome processes
pkill -f chrome
pkill -f chromedriver

# Clean Chrome temporary files
rm -rf /tmp/.com.google.Chrome.*
rm -rf ~/.config/google-chrome/Singleton*

# Restart application
sudo systemctl restart tracker-delivery
```

**D. Environment Variables**
```bash
# Set correct environment variables
export CHROME_BIN="/usr/bin/google-chrome"
export CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"

# Add to systemd service file
sudo systemctl edit tracker-delivery
# Add:
# [Service]
# Environment=CHROME_BIN=/usr/bin/google-chrome
# Environment=CHROMEDRIVER_PATH=/usr/local/bin/chromedriver
```

### 4. Memory Issues

**Symptoms:**
```
Application becomes slow or unresponsive
Parser failures increase over time
System out of memory errors
High memory usage in monitoring
```

**Diagnostic Steps:**
```bash
# 1. Check current memory usage
free -h
ps aux --sort=-%mem | head -20

# 2. Monitor memory over time
watch -n 5 'free -h && echo "Chrome processes:" && ps aux | grep chrome | wc -l'

# 3. Check for memory leaks
# Start application and monitor baseline
ps -o pid,vsz,rss,comm -p $(pgrep -f "rails server")

# Run several parse operations
bin/rails runner "5.times { |i| puts i; GrabParserService.new.parse('test-url') }"

# Check memory again
ps -o pid,vsz,rss,comm -p $(pgrep -f "rails server")
```

**Solutions:**

**A. Memory Leak in WebDriver**
```bash
# Check for orphaned Chrome processes
ps aux | grep chrome | grep -v grep
ps aux | grep chromedriver | grep -v grep

# Kill orphaned processes
pkill -f "chrome.*headless"
pkill -f chromedriver
```

**B. Insufficient Memory Allocation**
```bash
# Check swap usage
swapon --show
free -h

# Add swap if needed (Ubuntu/Debian)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**C. Memory Limits in systemd**
```bash
# Check current limits
systemctl show tracker-delivery | grep Memory

# Increase memory limit
sudo systemctl edit tracker-delivery
# Add:
# [Service]
# MemoryMax=4G
# MemoryHigh=3G

sudo systemctl daemon-reload
sudo systemctl restart tracker-delivery
```

**D. Application-level Memory Management**
```ruby
# Add to config/environments/production.rb
Rails.application.configure do
  # Force garbage collection after each parse
  config.after_parse_gc = true
  
  # Limit concurrent operations
  config.max_concurrent_parsers = 2
end
```

### 5. Network and Timeout Issues

**Symptoms:**
```
Timeout::Error in logs
Network timeouts during parsing
Slow parse times in production
Connection refused errors
```

**Diagnostic Steps:**
```bash
# 1. Test network connectivity
ping -c 5 food.grab.com
ping -c 5 gofood.co.id
traceroute food.grab.com

# 2. Test HTTP connectivity
curl -w "time_total: %{time_total}\n" -o /dev/null -s "https://food.grab.com"
curl -w "time_total: %{time_total}\n" -o /dev/null -s "https://gofood.co.id"

# 3. Check DNS resolution
nslookup food.grab.com
dig food.grab.com

# 4. Test from application
bin/rails runner "
  require 'net/http'
  require 'timeout'
  
  start = Time.current
  begin
    Timeout.timeout(10) do
      uri = URI('https://food.grab.com')
      response = Net::HTTP.get_response(uri)
      puts 'Status: ' + response.code
    end
  rescue => e
    puts 'Error: ' + e.message
  end
  puts 'Duration: ' + (Time.current - start).to_s + 's'
"
```

**Solutions:**

**A. Increase Timeout Values**
```ruby
# In parser service files
class GrabParserService < RetryableParser
  TIMEOUT_SECONDS = 30  # Increase from 20
end

class GojekParserService < RetryableParser
  TIMEOUT_SECONDS = 90  # Increase from 60 for very slow networks
end
```

**B. Configure Chrome for Slow Networks**
```ruby
# Add to Chrome options
options.add_argument('--timeout=60000')
options.add_argument('--disable-background-timer-throttling')
options.add_argument('--disable-renderer-backgrounding')
options.add_argument('--disable-backgrounding-occluded-windows')
```

**C. Network Configuration**
```bash
# Increase system network timeouts
echo 'net.ipv4.tcp_syn_retries = 3' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout = 30' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure DNS
echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf
echo 'nameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf
```

**D. Proxy Configuration (if needed)**
```bash
# Set proxy environment variables
export HTTP_PROXY=http://proxy-server:port
export HTTPS_PROXY=http://proxy-server:port
export NO_PROXY=localhost,127.0.0.1

# Add to Chrome options
options.add_argument("--proxy-server=http://proxy-server:port")
```

### 6. Data Extraction Issues

**Symptoms:**
```
Parser returns partial data
Missing address, rating, or other fields
Data format inconsistencies
Extraction returns empty strings
```

**Diagnostic Steps:**
```bash
# 1. Check page structure manually
bin/rails runner "
  require 'selenium-webdriver'
  options = Selenium::WebDriver::Chrome::Options.new(args: ['--headless'])
  driver = Selenium::WebDriver.for(:chrome, options: options)
  driver.get('YOUR_TEST_URL')
  
  # Check for expected elements
  puts 'Page title: ' + driver.title
  puts 'Address elements: ' + driver.find_elements(:css, '[data-testid*=\"address\"]').size.to_s
  puts 'Rating elements: ' + driver.find_elements(:css, '[data-testid*=\"rating\"]').size.to_s
  
  # Save page source for analysis
  File.write('/tmp/page_debug.html', driver.page_source)
  puts 'Page source saved to /tmp/page_debug.html'
  
  driver.quit
"

# 2. Compare with working URLs
# Test with known working URL vs failing URL
```

**Solutions:**

**A. Update CSS Selectors**
```ruby
# Check current selectors in parser services
# Look for elements like:
driver.find_element(:css, "selector-that-might-be-outdated")

# Update with current selectors from page inspection
# Use browser dev tools to find current selectors
```

**B. Add Wait Conditions**
```ruby
# Ensure elements are loaded before extraction
wait = Selenium::WebDriver::Wait.new(timeout: 10)
wait.until { driver.find_element(:css, "your-selector").displayed? }
```

**C. Handle Dynamic Content**
```ruby
# For JavaScript-loaded content
driver.execute_script("return document.readyState") == "complete"
sleep(2)  # Allow JS to complete

# Wait for specific content
wait.until { driver.find_elements(:css, "your-selector").any? }
```

### 7. Logging and Debugging Issues

**Symptoms:**
```
Missing log entries
Unclear error messages
Cannot trace execution flow
Performance bottlenecks unclear
```

**Enable Debug Logging:**
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.log_level = :debug  # Temporarily for debugging
  config.logger = Logger.new(STDOUT) if ENV['DEBUG_STDOUT']
end
```

**Enhanced Logging Commands:**
```bash
# Debug specific parser
DEBUG_STDOUT=true bin/rails runner "
  Rails.logger.level = Logger::DEBUG
  result = GrabParserService.new.parse('YOUR_URL')
  puts 'Final result: ' + result.inspect
"

# Monitor logs in real-time
tail -f log/production.log | grep -E "(Grab|GoJek|RetryableParser|ERROR|WARN)"

# Filter specific operations
journalctl -u tracker-delivery.service | grep "parser"
```

**Log Analysis:**
```bash
# Count error types
grep "ERROR" log/production.log | awk '{print $NF}' | sort | uniq -c

# Performance analysis
grep "SUCCESS\|duration" log/production.log | tail -20

# Circuit breaker events
grep -E "Circuit breaker|OPENED|RESET" log/production.log
```

## Performance Troubleshooting

### Slow Parse Times

**Diagnostic:**
```bash
# Measure parse time components
bin/rails runner "
  start = Time.current
  puts 'Starting parse at: ' + start.to_s
  
  result = GrabParserService.new.parse('YOUR_URL')
  
  total_time = Time.current - start
  puts 'Total parse time: ' + total_time.to_s + 's'
  puts 'Result: ' + (result ? 'Success' : 'Failed')
"
```

**Solutions:**
1. Disable images: `--disable-images`
2. Reduce wait times in parser logic
3. Use faster CSS selectors
4. Enable browser caching: `--aggressive-cache-discard`

### High Resource Usage

**Monitor Resources:**
```bash
# Continuous monitoring
watch -n 2 'echo "=== Memory ===" && free -h && echo "=== CPU ===" && top -bn1 | head -10 && echo "=== Chrome Processes ===" && ps aux | grep chrome | wc -l'

# Detailed process analysis
ps aux --sort=-%mem | head -20
lsof -p $(pgrep -f "rails server") | wc -l
```

**Optimization:**
```bash
# Limit Chrome processes
export CHROME_FLAGS="--max-renderers=1 --single-process"

# Optimize system
echo 3 | sudo tee /proc/sys/vm/drop_caches  # Clear page cache
```

## Emergency Procedures

### Complete Service Recovery

**1. Stop All Services:**
```bash
sudo systemctl stop tracker-delivery
pkill -f chrome
pkill -f chromedriver
pkill -f rails
```

**2. Clean Temporary Files:**
```bash
rm -rf /tmp/.com.google.Chrome.*
rm -rf ~/.config/google-chrome/Singleton*
rm -rf /tmp/chromedriver*
```

**3. Reset Circuit Breakers:**
```bash
bin/rails runner "
  GrabParserService.circuit_breaker_failures = 0
  GrabParserService.circuit_breaker_opened_at = nil
  GojekParserService.circuit_breaker_failures = 0
  GojekParserService.circuit_breaker_opened_at = nil
"
```

**4. Restart Services:**
```bash
sudo systemctl start tracker-delivery
sleep 10
curl http://localhost:3000/health
```

### Database Issues

**Backup and Recovery:**
```bash
# Backup current database
cp db/production.sqlite3 db/production.sqlite3.backup.$(date +%Y%m%d_%H%M%S)

# Reset database if corrupted
bin/rails db:reset RAILS_ENV=production

# Restore from backup
cp db/production.sqlite3.backup.TIMESTAMP db/production.sqlite3
```

## Monitoring and Prevention

### Automated Health Checks

**Create monitoring script:**
```bash
#!/bin/bash
# /usr/local/bin/parser_health_check.sh

LOG_FILE="/var/log/tracker-delivery/health_check.log"
ALERT_EMAIL="admin@yourdomain.com"

# Test both parsers
GRAB_STATUS=$(curl -s http://localhost:3000/health/parsers | jq -r '.grab.status // "error"')
GOJEK_STATUS=$(curl -s http://localhost:3000/health/parsers | jq -r '.gojek.status // "error"')

# Check circuit breakers
CB_STATUS=$(curl -s http://localhost:3000/health | jq -r '.circuit_breaker')

# Log results
echo "$(date): Grab=$GRAB_STATUS, GoJek=$GOJEK_STATUS" >> $LOG_FILE

# Send alerts
if [[ "$GRAB_STATUS" != "ok" ]] || [[ "$GOJEK_STATUS" != "ok" ]]; then
  echo "Parser health check failed at $(date)" | mail -s "TrackerDelivery Alert" $ALERT_EMAIL
fi
```

**Schedule with cron:**
```bash
# Add to crontab
*/10 * * * * /usr/local/bin/parser_health_check.sh
```

### Preventive Maintenance

**Daily maintenance script:**
```bash
#!/bin/bash
# /usr/local/bin/daily_maintenance.sh

# Clean temporary files
find /tmp -name ".com.google.Chrome.*" -type d -mtime +1 -exec rm -rf {} +
find /tmp -name "chromedriver*" -mtime +1 -delete

# Rotate logs
logrotate /etc/logrotate.d/tracker-delivery

# Health check
/usr/local/bin/parser_health_check.sh

# Restart if memory usage too high
MEMORY_USAGE=$(ps -o pid,vsz --no-headers -p $(pgrep -f "rails server") | awk '{print $2}')
if [ "$MEMORY_USAGE" -gt 1000000 ]; then  # 1GB in KB
  systemctl restart tracker-delivery
  echo "$(date): Restarted due to high memory usage: ${MEMORY_USAGE}KB" >> /var/log/tracker-delivery/maintenance.log
fi
```

## Support Escalation

### When to Escalate

**Critical Issues (Immediate escalation):**
- All parsers failing for >30 minutes
- Circuit breaker permanently open
- System resource exhaustion
- Security vulnerabilities discovered

**Major Issues (4-hour SLA):**
- Single parser consistently failing
- Performance degradation >50%
- Memory leaks detected
- Data extraction accuracy <90%

**Minor Issues (24-hour SLA):**
- Occasional parse failures
- Minor performance issues
- Non-critical feature requests

### Information to Collect

**For All Issues:**
1. Error logs (last 100 lines)
2. System resource usage
3. Application version and environment
4. Reproduction steps
5. Impact assessment

**Commands to gather information:**
```bash
# System info package
mkdir /tmp/debug_info
cd /tmp/debug_info

# System information
uname -a > system_info.txt
free -h > memory_info.txt
df -h > disk_info.txt
ps aux --sort=-%mem | head -20 > process_info.txt

# Application logs
tail -100 /var/log/tracker-delivery/production.log > app_logs.txt
journalctl -u tracker-delivery.service --since "1 hour ago" > systemd_logs.txt

# Parser status
curl -s http://localhost:3000/health > health_status.json
curl -s http://localhost:3000/health/parsers > parser_status.json

# Package everything
tar -czf tracker_delivery_debug_$(date +%Y%m%d_%H%M%S).tar.gz *
```

This troubleshooting guide provides comprehensive coverage of common issues and their solutions. Regular monitoring and preventive maintenance following these procedures will ensure reliable operation of TrackerDelivery Parser System v5.0.