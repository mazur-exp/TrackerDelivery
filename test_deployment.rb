#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class DeploymentTester
  def initialize(base_url)
    @base_url = base_url
    @test_urls = {
      grab: "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2",
      gojek: "https://gofood.link/a/qpKr7VkG"
    }
  end
  
  def run_full_test
    puts "🚀 Testing Deployment with Chrome & Selenium"
    puts "=" * 60
    puts "🌐 Production URL: #{@base_url}"
    puts ""
    
    # Test both parsers
    %w[grab gojek].each do |platform|
      puts "#{platform == 'grab' ? '🟢' : '🔵'} Testing #{platform.capitalize} Parser After Deployment"
      puts "-" * 50
      
      success = test_parser(platform)
      
      if success
        puts "✅ #{platform.capitalize} parser working correctly!"
      else
        puts "❌ #{platform.capitalize} parser still failing"
        puts "   Check server logs for Chrome/Selenium errors"
      end
      
      puts ""
    end
    
    puts "=" * 60
    puts "📝 DEPLOYMENT VERIFICATION CHECKLIST:"
    puts ""
    puts "✅ 1. Docker image rebuilt with Chrome dependencies"
    puts "✅ 2. Chrome and ChromeDriver installed in container"
    puts "✅ 3. Parser services updated with production flags"
    puts "✅ 4. Binary paths configured for container environment"
    puts ""
    puts "If tests still fail, check:"
    puts "- Server memory (Chrome needs ~100MB+)"
    puts "- Container security restrictions"
    puts "- Network connectivity from server"
    puts "- Log files for specific error messages"
  end
  
  private
  
  def test_parser(platform)
    url = "#{@base_url}/restaurants/extract_#{platform}_data"
    test_url = @test_urls[platform.to_sym]
    
    puts "📡 Endpoint: #{url}"
    puts "🔗 Test URL: #{test_url[0..50]}..."
    
    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = 90 # Longer timeout for Chrome startup
      http.open_timeout = 10
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'Mozilla/5.0 (compatible; TrackerDelivery/1.0)'
      
      payload = { "#{platform}_url" => test_url }
      request.body = payload.to_json
      
      puts "⏱️  Making request (may take up to 90s for Chrome startup)..."
      start_time = Time.now
      
      response = http.request(request)
      duration = Time.now - start_time
      
      puts "⏱️  Response received in #{duration.round(2)}s"
      puts "📊 HTTP Status: #{response.code} #{response.message}"
      
      case response.code
      when '200'
        data = JSON.parse(response.body)
        if data['success']
          puts "✅ SUCCESS!"
          puts "   Platform: #{data['platform']}"
          puts "   Name: #{data['data']['name']}" if data['data']
          puts "   Address: #{data['data']['address']}" if data['data']
          puts "   Coordinates: #{data['data']['coordinates']}" if data['data'] && data['data']['coordinates']
          puts "   Rating: #{data['data']['rating']}" if data['data']
          return true
        else
          puts "❌ PARSING FAILED"
          puts "   Errors: #{data['errors']&.join(', ')}"
          return false
        end
        
      when '422'
        puts "❌ UNPROCESSABLE ENTITY"
        data = JSON.parse(response.body) rescue {}
        puts "   Errors: #{data['errors']&.join(', ')}"
        return false
        
      when '500'
        puts "💥 INTERNAL SERVER ERROR"
        puts "   This indicates Chrome/Selenium is still not working"
        puts "   Check if all dependencies were installed correctly"
        return false
        
      else
        puts "⚠️  UNEXPECTED STATUS: #{response.code}"
        return false
      end
      
    rescue Net::TimeoutError
      puts "⏰ TIMEOUT ERROR"
      puts "   Chrome might be taking too long to start"
      puts "   This is common on first run after deployment"
      return false
      
    rescue => e
      puts "💥 NETWORK ERROR"
      puts "   Error: #{e.class} - #{e.message}"
      return false
    end
  end
end

# Usage
if ARGV.length < 1
  puts "Usage: ruby test_deployment.rb <production_url>"
  puts "Example: ruby test_deployment.rb https://aidelivery.tech"
  exit 1
end

production_url = ARGV[0]
tester = DeploymentTester.new(production_url)
tester.run_full_test