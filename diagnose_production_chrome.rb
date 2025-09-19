#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class ProductionChromeChecker
  def initialize(base_url)
    @base_url = base_url
  end
  
  def run_diagnostics
    puts "🔧 Production Chrome & Selenium Diagnostics"
    puts "=" * 60
    puts "🌐 Production URL: #{@base_url}"
    puts ""
    
    # 1. Check if endpoint is responsive
    check_endpoints
    
    puts ""
    puts "=" * 60
    puts "🚨 POSSIBLE PRODUCTION ISSUES:"
    puts ""
    
    puts "1. 🤖 Chrome/ChromeDriver Issues:"
    puts "   ❌ Chrome not installed on production server"
    puts "   ❌ ChromeDriver version mismatch"
    puts "   ❌ Missing Chrome dependencies in Docker/container"
    puts "   ❌ Chrome flags incompatible with server environment"
    puts ""
    
    puts "2. 🐳 Container/Docker Issues:"
    puts "   ❌ Missing: apt-get install google-chrome-stable"
    puts "   ❌ Missing: fonts-liberation libappindicator3-1"
    puts "   ❌ Missing: libasound2 libatk-bridge2.0-0 libdrm2"
    puts "   ❌ Missing: libxkbcommon0 libxss1 libgbm1"
    puts "   ❌ Need: --no-sandbox --disable-dev-shm-usage flags"
    puts ""
    
    puts "3. 💾 System Resources:"
    puts "   ❌ Insufficient memory for Chrome (needs ~100MB+)"
    puts "   ❌ Timeout too short for slow server"
    puts "   ❌ /tmp directory not writable"
    puts ""
    
    puts "4. 🔒 Network/Security:"
    puts "   ❌ Firewall blocking external requests"
    puts "   ❌ User-agent detection blocking requests"
    puts "   ❌ Rate limiting from target sites"
    puts ""
    
    puts "=" * 60
    puts "📋 PRODUCTION SETUP CHECKLIST:"
    puts ""
    puts "For Heroku/Docker deployment, ensure Dockerfile has:"
    puts ""
    puts "```dockerfile"
    puts "# Install Chrome dependencies"
    puts "RUN apt-get update && apt-get install -y \\"
    puts "    wget \\"
    puts "    gnupg \\"
    puts "    unzip \\"
    puts "    curl \\"
    puts "    xvfb"
    puts ""
    puts "# Install Chrome"
    puts "RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \\"
    puts "    && sh -c 'echo \"deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\" >> /etc/apt/sources.list.d/google.list' \\"
    puts "    && apt-get update \\"
    puts "    && apt-get install -y google-chrome-stable \\"
    puts "    && rm -rf /var/lib/apt/lists/*"
    puts ""
    puts "# Install ChromeDriver"
    puts "RUN CHROMEDRIVER_VERSION=$(curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE) \\"
    puts "    && wget -N http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip \\"
    puts "    && unzip chromedriver_linux64.zip \\"
    puts "    && rm chromedriver_linux64.zip \\"
    puts "    && mv chromedriver /usr/local/bin/chromedriver \\"
    puts "    && chmod +x /usr/local/bin/chromedriver"
    puts "```"
    puts ""
    
    puts "For Heroku buildpack, add to Gemfile:"
    puts "```ruby"
    puts "gem 'selenium-webdriver'"
    puts "```"
    puts ""
    puts "And add buildpacks:"
    puts "heroku buildpacks:add --index 1 heroku/google-chrome"
    puts "heroku buildpacks:add --index 2 heroku/chromedriver"
    puts "heroku buildpacks:add --index 3 heroku/ruby"
    puts ""
  end
  
  private
  
  def check_endpoints
    endpoints = [
      '/restaurants/extract_grab_data',
      '/restaurants/extract_gojek_data',
      '/restaurants/extract_data'
    ]
    
    endpoints.each do |endpoint|
      puts "🔍 Testing endpoint: #{endpoint}"
      
      begin
        uri = URI("#{@base_url}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.read_timeout = 5
        http.open_timeout = 5
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = {}.to_json
        
        response = http.request(request)
        
        if response.code == '422'
          puts "   ✅ Endpoint accessible (422 expected for empty request)"
        elsif response.code == '500'
          puts "   ❌ Internal Server Error - likely Chrome/Selenium issue"
        elsif response.code.start_with?('4')
          puts "   ⚠️  Client error (#{response.code}) - check routing/auth"
        else
          puts "   ❓ Unexpected response: #{response.code}"
        end
        
      rescue Net::TimeoutError
        puts "   ⏰ Timeout - server might be slow or unresponsive"
      rescue => e
        puts "   💥 Network error: #{e.class} - #{e.message}"
      end
    end
  end
end

# Usage
if ARGV.length < 1
  puts "Usage: ruby diagnose_production_chrome.rb <production_url>"
  puts "Example: ruby diagnose_production_chrome.rb https://aidelivery.tech"
  exit 1
end

production_url = ARGV[0]
checker = ProductionChromeChecker.new(production_url)
checker.run_diagnostics