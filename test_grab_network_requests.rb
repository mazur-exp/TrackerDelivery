#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"
require "json"

class GrabNetworkAnalyzer
  TIMEOUT_SECONDS = 30

  def analyze_network_requests(url)
    begin
      Timeout::timeout(TIMEOUT_SECONDS) do
        options = setup_chrome_options
        
        # Enable performance logging to capture network requests
        options.logging_prefs = { performance: 'ALL' }
        
        driver = Selenium::WebDriver.for :chrome, options: options
        
        puts "=== Navigating to URL and capturing network requests ==="
        puts url
        
        driver.navigate.to url
        
        # Wait for page to load completely
        sleep(5)
        
        puts "\n=== Analyzing Network Requests ==="
        
        # Get performance logs (includes network requests)
        logs = driver.logs.get(:performance)
        
        api_requests = []
        
        logs.each do |log|
          begin
            message = JSON.parse(log.message)
            
            # Look for network requests
            if message['message']['method'] == 'Network.responseReceived'
              response = message['message']['params']['response']
              url = response['url']
              
              # Filter for interesting API calls
              if url.include?('grab.com') && (
                url.include?('api') || 
                url.include?('location') ||
                url.include?('address') ||
                url.include?('restaurant') ||
                url.include?('merchant') ||
                url.include?('geocode')
              )
                api_requests << {
                  url: url,
                  status: response['status'],
                  headers: response['headers']
                }
              end
            end
          rescue JSON::ParserError
            next
          end
        end
        
        puts "Found #{api_requests.length} relevant API requests:"
        
        api_requests.each_with_index do |request, index|
          puts "\n#{index + 1}. #{request[:url]}"
          puts "   Status: #{request[:status]}"
          
          # Try to get response body if possible
          if request[:status] == 200
            puts "   ✅ Successful request - could contain address data"
          end
        end
        
        # Try to execute some JavaScript to get more data
        puts "\n=== Trying JavaScript execution for more data ==="
        
        # Try to access window object data
        js_data_checks = [
          "return window.__INITIAL_STATE__",
          "return window.__PRELOADED_STATE__", 
          "return window.__GRAB_DATA__",
          "return window.pageData",
          "return window.restaurantData",
          "return JSON.stringify(window.localStorage)",
          "return JSON.stringify(window.sessionStorage)"
        ]
        
        js_data_checks.each do |js|
          begin
            result = driver.execute_script(js)
            if result && !result.to_s.empty?
              puts "#{js}: #{result.to_s[0..200]}..."
              
              # Parse JSON if possible and look for address
              if result.is_a?(String) && result.start_with?('{')
                parsed = JSON.parse(result)
                address_info = find_address_in_data(parsed)
                puts "  Found address info: #{address_info}" if address_info
              end
            end
          rescue => e
            # Silently continue if JS execution fails
          end
        end
        
        # Try to get data from specific elements that might load dynamically
        puts "\n=== Checking for dynamically loaded content ==="
        
        # Wait a bit more and check again
        sleep(3)
        
        # Look for any elements that might contain address after async loading
        address_selectors = [
          "//*[contains(text(), 'Jl.')]",
          "//*[contains(text(), 'Street')]", 
          "//*[contains(text(), 'Road')]",
          "//*[contains(text(), 'Padonan')]",
          "//*[contains(@data-address, '')]",
          "//*[contains(@title, 'address')]"
        ]
        
        address_selectors.each do |selector|
          begin
            elements = driver.find_elements(:xpath, selector)
            if elements.length > 0
              puts "Found #{elements.length} elements with selector: #{selector}"
              elements.first(2).each do |element|
                text = element.text.strip
                puts "  Text: #{text}" if text.length > 0 && text.length < 200
              end
            end
          rescue
            next
          end
        end
        
        driver.quit
        api_requests
      end
    rescue Timeout::Error
      puts "Timeout after #{TIMEOUT_SECONDS} seconds"
      driver&.quit
      []
    rescue => e
      puts "Error: #{e.message}"
      driver&.quit
      []
    end
  end

  private

  def setup_chrome_options
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-web-security")
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1")
    
    # Enable performance logging
    options.add_argument("--enable-logging")
    options.add_argument("--log-level=0")
    
    options
  end

  def find_address_in_data(data, path = "", max_depth = 3)
    return nil if max_depth <= 0
    
    case data
    when Hash
      data.each do |key, value|
        current_path = path.empty? ? key.to_s : "#{path}.#{key}"
        
        # Check if this looks like address data
        if key.to_s.downcase.match?(/address|street|location|area|district/) && 
           value.is_a?(String) && value.include?('Jl.')
          return "#{current_path}: #{value}"
        end
        
        # Look for Indonesian street indicators
        if value.is_a?(String) && (value.include?('Jl. Raya') || value.include?('Padonan'))
          return "#{current_path}: #{value}"
        end
        
        # Recursively search in nested data
        result = find_address_in_data(value, current_path, max_depth - 1)
        return result if result
      end
    when Array
      data.each_with_index do |item, index|
        result = find_address_in_data(item, "#{path}[#{index}]", max_depth - 1)
        return result if result
      end
    end
    
    nil
  end
end

# Test the analyzer
url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
analyzer = GrabNetworkAnalyzer.new

puts "🕵️ Analyzing network requests and dynamic content for address data"
puts "URL: #{url}"
puts "=" * 80

requests = analyzer.analyze_network_requests(url)

puts "\n" + "=" * 80  
puts "CONCLUSION"
puts "=" * 80
if requests.empty?
  puts "❌ No relevant API requests found that might contain address data"
  puts "📝 Address might be:"
  puts "   1. Hardcoded in frontend JavaScript"
  puts "   2. Loaded through authenticated API calls"
  puts "   3. Not available through public APIs"
  puts "   4. Requires user authentication to access"
else
  puts "✅ Found #{requests.length} API requests that might contain address data"
  puts "📋 Further investigation needed to extract actual address content"
end