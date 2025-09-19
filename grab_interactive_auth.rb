#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"
require "json"

class GrabInteractiveAuth
  TIMEOUT_SECONDS = 120  # 2 minutes for manual login
  
  def initialize
    @restaurant_url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
    @restaurant_id = "6-C4J1HGK3N33WR2"
  end
  
  def interactive_login_and_extract
    driver = nil
    
    begin
      puts "🚀 Starting interactive browser session..."
      puts "=" * 80
      
      # Setup Chrome driver in visible mode (no headless)
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--disable-web-security")
      options.add_argument("--disable-features=VizDisplayCompositor")
      options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36")
      
      # Enable performance logging to capture network requests
      options.logging_prefs = { performance: 'ALL' }
      
      driver = Selenium::WebDriver.for :chrome, options: options
      
      puts "📱 Opening Grab restaurant page..."
      driver.navigate.to @restaurant_url
      
      sleep(2)
      
      puts "🔑 Please log in to your Grab account in the browser window that just opened."
      puts "📍 After logging in, the address should become visible on the restaurant page."
      puts "⏱️  You have #{TIMEOUT_SECONDS} seconds to complete the login process."
      puts "✋ Press ENTER in this terminal when you've successfully logged in..."
      
      # Wait for user to press enter
      STDIN.gets
      
      puts "\n🔍 Checking for address data after authentication..."
      
      # Give page time to update after login
      sleep(3)
      
      # Method 1: Check DOM for address elements
      puts "\n=== Method 1: DOM Address Search ==="
      address_found = search_dom_for_address(driver)
      
      # Method 2: Check JSON data again
      puts "\n=== Method 2: JSON Data Re-extraction ==="
      json_address = extract_json_address(driver)
      
      # Method 3: Check for new network requests after login
      puts "\n=== Method 3: Network Requests Analysis ==="
      network_data = analyze_network_requests(driver)
      
      # Method 4: Try JavaScript execution for authenticated data
      puts "\n=== Method 4: JavaScript Data Access ==="
      js_data = execute_js_for_address(driver)
      
      puts "\n" + "=" * 80
      puts "🏠 ADDRESS EXTRACTION RESULTS"
      puts "=" * 80
      
      results = []
      results << "DOM Search: #{address_found}" if address_found
      results << "JSON Data: #{json_address}" if json_address  
      results << "Network: #{network_data}" if network_data
      results << "JavaScript: #{js_data}" if js_data
      
      if results.any?
        puts "✅ SUCCESS! Found address data:"
        results.each { |result| puts "   #{result}" }
      else
        puts "❌ No address data found even after authentication"
        puts "📝 Possible reasons:"
        puts "   - Address is still not displayed for this restaurant"
        puts "   - Different authentication method required"
        puts "   - Restaurant doesn't have public address"
      end
      
      puts "\n🔄 Keeping browser open for 30 seconds for manual inspection..."
      puts "💡 You can manually inspect the page elements during this time."
      sleep(30)
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
    ensure
      if driver
        puts "\n🚪 Closing browser..."
        driver.quit
      end
    end
  end
  
  private
  
  def search_dom_for_address(driver)
    address_selectors = [
      # Indonesian address patterns
      "//*[contains(text(), 'Jl. Raya')]",
      "//*[contains(text(), 'Padonan')]", 
      "//*[contains(text(), 'Jl.') and contains(text(), 'Raya')]",
      
      # Generic address selectors
      "//div[contains(@class, 'address')]//text()[normalize-space()]",
      "//span[contains(@class, 'address')]//text()[normalize-space()]",
      "//*[contains(@data-address, '.')]",
      "//*[contains(@aria-label, 'address')]",
      
      # Location/street patterns
      "//*[contains(text(), 'Street') or contains(text(), 'Road')]",
      "//*[contains(text(), 'Tibubeneng') and string-length(text()) > 20]"
    ]
    
    found_addresses = []
    
    address_selectors.each do |selector|
      begin
        elements = driver.find_elements(:xpath, selector)
        elements.each do |element|
          text = element.text.strip
          if text.length > 10 && (text.include?('Jl.') || text.include?('Padonan') || 
                                   text.include?('Street') || text.include?('Road'))
            found_addresses << text
            puts "   Found: #{text}"
          end
        end
      rescue => e
        puts "   Error with selector #{selector}: #{e.message}"
      end
    end
    
    found_addresses.uniq.first
  end
  
  def extract_json_address(driver)
    begin
      scripts = driver.find_elements(:css, "script")
      
      scripts.each do |script|
        content = script.attribute("innerHTML")
        next unless content && content.include?('ssrRestaurantData')
        
        # Extract and parse JSON
        json_start = content.index('{"props"')
        next unless json_start
        
        json_content = content[json_start..-1]
        
        # Find JSON end
        brace_count = 0
        json_end = nil
        json_content.each_char.with_index do |char, i|
          brace_count += 1 if char == '{'
          brace_count -= 1 if char == '}'
          if brace_count == 0
            json_end = i
            break
          end
        end
        
        next unless json_end
        
        json_data = json_content[0..json_end]
        parsed = JSON.parse(json_data)
        
        # Check restaurant address data
        restaurant_data = parsed.dig('props', 'pageProps', 'ssrRestaurantData')
        if restaurant_data && restaurant_data['address']
          address_data = restaurant_data['address']
          
          puts "   Address object: #{address_data.inspect}"
          
          # Check if any fields are now populated
          populated_fields = address_data.select { |k, v| v && !v.to_s.empty? }
          if populated_fields.any?
            return populated_fields.map { |k, v| "#{k}: #{v}" }.join(', ')
          end
        end
        
        break
      end
      
      nil
    rescue => e
      puts "   JSON parsing error: #{e.message}"
      nil
    end
  end
  
  def analyze_network_requests(driver)
    begin
      logs = driver.logs.get(:performance)
      
      api_calls = []
      logs.each do |log|
        message = JSON.parse(log.message)
        if message.dig('message', 'method') == 'Network.responseReceived'
          response = message.dig('message', 'params', 'response')
          url = response['url']
          
          # Look for location/address API calls
          if url.include?('location') || url.include?('address') || url.include?('geocode')
            api_calls << {
              url: url,
              status: response['status']
            }
            puts "   API Call: #{url} (#{response['status']})"
          end
        end
      end
      
      api_calls.any? ? "Found #{api_calls.length} location-related API calls" : nil
    rescue => e
      puts "   Network analysis error: #{e.message}"
      nil
    end
  end
  
  def execute_js_for_address(driver)
    js_commands = [
      # Try to access restaurant data from window
      "return window.__GRAB_RESTAURANT_DATA__",
      "return window.__INITIAL_DATA__",
      "return window.restaurantData",
      
      # Try to get address from DOM using different methods
      "return document.querySelector('[data-address]')?.getAttribute('data-address')",
      "return document.querySelector('.address')?.textContent",
      "return Array.from(document.querySelectorAll('*')).find(el => el.textContent.includes('Jl. Raya'))?.textContent",
      "return Array.from(document.querySelectorAll('*')).find(el => el.textContent.includes('Padonan'))?.textContent",
      
      # Search in all text nodes
      """
      return Array.from(document.evaluate('//text()[contains(., \"Jl.\") or contains(., \"Street\")]', document, null, XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE, null))
        .map((node, i) => i < 5 ? node.textContent.trim() : null)
        .filter(text => text && text.length > 10)
        .join(' | ')
      """
    ]
    
    js_commands.each do |js|
      begin
        result = driver.execute_script(js)
        if result && !result.to_s.strip.empty?
          clean_result = result.to_s.strip
          if clean_result.include?('Jl.') || clean_result.include?('Padonan') || clean_result.include?('Street')
            puts "   JS Result: #{clean_result}"
            return clean_result
          end
        end
      rescue => e
        # Silently continue on JS errors
      end
    end
    
    nil
  end
end

# Run the interactive session
puts "🏪 Grab Restaurant Address Extractor - Interactive Mode"
puts "Restaurant: Prana Kitchen - Tibubeneng"
puts ""

auth = GrabInteractiveAuth.new
auth.interactive_login_and_extract