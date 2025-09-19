#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class ProductionParsingDebug
  def initialize(base_url)
    @base_url = base_url
    @test_urls = {
      grab: "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2",
      gojek: "https://gofood.link/a/qpKr7VkG"
    }
  end
  
  def debug_parsing_issues
    puts "🔍 Debugging Production Parsing Issues"
    puts "=" * 60
    puts "🌐 Production URL: #{@base_url}"
    puts ""
    
    # Test each parser
    %w[grab gojek].each do |platform|
      puts "#{platform == 'grab' ? '🟢' : '🔵'} Testing #{platform.capitalize} Parser"
      puts "-" * 40
      
      test_individual_parser(platform)
      puts ""
    end
    
    puts "=" * 60
    puts "🚨 COMMON PRODUCTION ISSUES TO CHECK:"
    puts ""
    puts "1. 🤖 Chrome/Selenium Setup:"
    puts "   - Chrome browser installed on server?"
    puts "   - ChromeDriver version compatibility?"
    puts "   - Headless mode working?"
    puts ""
    puts "2. 🔒 Network/Security:"
    puts "   - Server can access external URLs?"
    puts "   - Firewall blocking Selenium?"
    puts "   - User-Agent restrictions?"
    puts ""
    puts "3. 💾 Server Resources:"
    puts "   - Enough memory for Chrome?"
    puts "   - Timeout settings appropriate?"
    puts "   - /tmp directory writable?"
    puts ""
    puts "4. 🐳 Docker/Container Issues:"
    puts "   - Chrome dependencies installed?"
    puts "   - Display/X11 forwarding setup?"
    puts "   - Correct Chrome flags for containers?"
    puts ""
    puts "5. 🔧 Rails Environment:"
    puts "   - All gems installed in production?"
    puts "   - Environment variables set?"
    puts "   - Log level showing errors?"
  end
  
  private
  
  def test_individual_parser(platform)
    url = "#{@base_url}/restaurants/extract_#{platform}_data"
    test_url = @test_urls[platform.to_sym]
    
    puts "📡 Endpoint: #{url}"
    puts "🔗 Test URL: #{test_url[0..50]}..."
    
    begin
      # Make request to production endpoint
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = 60 # Long timeout for parsing
      http.open_timeout = 10
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'Mozilla/5.0 (compatible; TrackerDelivery/1.0)'
      
      payload = { "#{platform}_url" => test_url }
      request.body = payload.to_json
      
      puts "⏱️  Making request..."
      start_time = Time.now
      
      response = http.request(request)
      duration = Time.now - start_time
      
      puts "⏱️  Response received in #{duration.round(2)}s"
      puts "📊 HTTP Status: #{response.code} #{response.message}"
      
      if response.code == '200'
        begin
          data = JSON.parse(response.body)
          
          if data['success']
            puts "✅ SUCCESS!"
            puts "   Platform: #{data['platform']}"
            puts "   Name: #{data['data']['name']}" if data['data']
            puts "   Address: #{data['data']['address']}" if data['data']
            puts "   Coordinates: #{data['data']['coordinates']}" if data['data'] && data['data']['coordinates']
          else
            puts "❌ PARSING FAILED"
            puts "   Errors: #{data['errors']&.join(', ')}"
          end
          
        rescue JSON::ParserError => e
          puts "❌ INVALID JSON RESPONSE"
          puts "   Error: #{e.message}"
          puts "   Body preview: #{response.body[0..200]}..."
        end
        
      elsif response.code == '422'
        puts "❌ UNPROCESSABLE ENTITY"
        begin
          data = JSON.parse(response.body)
          puts "   Errors: #{data['errors']&.join(', ')}"
        rescue JSON::ParserError
          puts "   Raw response: #{response.body}"
        end
        
      elsif response.code == '500'
        puts "💥 INTERNAL SERVER ERROR"
        puts "   This usually means:"
        puts "   - Chrome/Selenium setup issue"
        puts "   - Missing dependencies"
        puts "   - Timeout or memory problems"
        puts "   - Check server logs for details"
        
      elsif response.code.start_with?('4')
        puts "🚫 CLIENT ERROR (#{response.code})"
        puts "   Could be routing, authentication, or request format issue"
        
      else
        puts "⚠️  UNEXPECTED STATUS: #{response.code}"
        puts "   Response: #{response.body[0..200]}"
      end
      
    rescue Net::TimeoutError => e
      puts "⏰ TIMEOUT ERROR"
      puts "   This suggests parsing is taking too long"
      puts "   Possible causes:"
      puts "   - Chrome startup issues"
      puts "   - Network connectivity problems" 
      puts "   - Infinite waiting for page load"
      
    rescue => e
      puts "💥 NETWORK ERROR"
      puts "   Error: #{e.class} - #{e.message}"
      puts "   This could indicate:"
      puts "   - DNS resolution issues"
      puts "   - SSL certificate problems"
      puts "   - Server connectivity issues"
    end
  end
end

# Usage
if ARGV.length < 1
  puts "Usage: ruby debug_production_parsing.rb <production_url>"
  puts "Example: ruby debug_production_parsing.rb https://your-app.herokuapp.com"
  puts "Example: ruby debug_production_parsing.rb https://your-domain.com"
  exit 1
end

production_url = ARGV[0]
debugger = ProductionParsingDebug.new(production_url)
debugger.debug_parsing_issues