#!/usr/bin/env ruby

require_relative 'app/services/grab_parser_service'
require "selenium-webdriver"
require "json"

# Test Grab mobile approach with Selenium
test_url = "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "Testing Grab mobile URL with Selenium mobile emulation:"
puts "=" * 80

driver = nil
begin
  # Setup Chrome with mobile user agent
  options = Selenium::WebDriver::Chrome::Options.new
  
  # Multiple mobile user agents to try
  mobile_user_agents = [
    "GrabFood/4.58.0 (iPhone; iOS 17.0; Scale/3.00)",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) GrabFood/4.58.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 GrabFood"
  ]
  
  # Use first mobile user agent
  options.add_argument("--user-agent=#{mobile_user_agents[0]}")
  
  # Mobile viewport
  options.add_argument("--window-size=375,812")
  
  # Standard options
  options.add_argument("--headless")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  
  puts "Starting Chrome with mobile emulation..."
  driver = Selenium::WebDriver.for(:chrome, options: options)
  
  # Track network requests (if possible)
  puts "Navigating to mobile URL..."
  driver.get(test_url)
  
  sleep(3)
  
  current_url = driver.current_url
  puts "Current URL: #{current_url}"
  
  # Check page title and content
  title = driver.title
  puts "Page title: #{title}"
  
  # Look for any JSON data in the page
  scripts = driver.find_elements(:css, "script")
  puts "Found #{scripts.length} script tags"
  
  scripts.each_with_index do |script, index|
    content = script.attribute("innerHTML")
    if content && content.include?("restaurant") && content.length > 100
      puts "\nScript #{index + 1} contains restaurant data:"
      puts content[0..500] + "..."
    end
  end
  
  # Look for specific data attributes
  meta_tags = driver.find_elements(:css, 'meta[property^="og:"], meta[name^="restaurant"], meta[content*="restaurant"]')
  puts "\nMeta tags with restaurant info:"
  meta_tags.each do |meta|
    property = meta.attribute("property") || meta.attribute("name")
    content = meta.attribute("content")
    puts "#{property}: #{content}" if property && content
  end
  
  # Try to find restaurant data in window object
  restaurant_data = driver.execute_script("return window.__INITIAL_STATE__ || window.__RESTAURANT_DATA__ || window.restaurantData || null")
  if restaurant_data
    puts "\nFound restaurant data in window object:"
    puts restaurant_data.inspect
  end
  
  # Extract JSON data from script tags more carefully
  puts "\nExtracting JSON data from script tags:"
  scripts.each_with_index do |script, index|
    content = script.attribute("innerHTML")
    if content && content.include?('"props"') && content.include?('ssrState')
      puts "\nFound SSR state in script #{index + 1}:"
      # Try to extract JSON
      begin
        # Look for {"props": pattern
        json_start = content.index('{"props"')
        if json_start
          # Find the end of this JSON object
          json_content = content[json_start..-1]
          # Basic extraction - look for the closing brace
          brace_count = 0
          json_end = nil
          json_content.each_char.with_index do |char, i|
            if char == '{'
              brace_count += 1
            elsif char == '}'
              brace_count -= 1
              if brace_count == 0
                json_end = i
                break
              end
            end
          end
          
          if json_end
            json_data = json_content[0..json_end]
            parsed = JSON.parse(json_data)
            puts "Successfully parsed JSON data!"
            puts "Keys: #{parsed.keys}"
            
            # Look for restaurant data in props
            if parsed['props']
              puts "\nProps keys: #{parsed['props'].keys}"
              
              # Check pageProps for restaurant data
              if parsed['props']['pageProps']
                puts "PageProps keys: #{parsed['props']['pageProps'].keys}"
                
                # Look for restaurant-related data
                parsed['props']['pageProps'].each do |key, value|
                  if key.to_s.downcase.include?('restaurant') || key.to_s.downcase.include?('merchant')
                    puts "\nFound restaurant data in #{key}:"
                    puts value.inspect[0..500] + "..."
                  elsif value.is_a?(Hash) && (value.to_s.include?('Prana Kitchen') || value.to_s.include?('address') || value.to_s.include?('rating'))
                    puts "\nFound potential restaurant data in #{key}:"
                    puts value.inspect[0..500] + "..."
                  end
                end
                
                # Specifically look at the restaurant data
                if parsed['props']['pageProps']['ssrRestaurantData']
                  restaurant_data = parsed['props']['pageProps']['ssrRestaurantData']
                  puts "\n--- DETAILED RESTAURANT DATA ---"
                  puts "Name: #{restaurant_data['name']}"
                  puts "Address object: #{restaurant_data['address'].inspect}" if restaurant_data['address']
                  puts "Location: #{restaurant_data['location']}" if restaurant_data['location']
                  puts "LatLng: #{restaurant_data['latlng']}" if restaurant_data['latlng']
                  puts "Full address data keys: #{restaurant_data['address'].keys}" if restaurant_data['address'].is_a?(Hash)
                end
              end
              
              # Check if there's initial data or state
              if parsed['props']['initialProps'] || parsed['props']['initialState']
                initial_key = parsed['props']['initialProps'] ? 'initialProps' : 'initialState'
                puts "\nFound #{initial_key}: #{parsed['props'][initial_key].keys}" if parsed['props'][initial_key].is_a?(Hash)
              end
            end
          end
        end
      rescue JSON::ParserError => e
        puts "JSON parsing failed: #{e.message}"
      end
    end
  end
  
  # Check local storage
  local_storage_data = driver.execute_script("return JSON.stringify(localStorage)")
  if local_storage_data && local_storage_data.include?("restaurant")
    puts "\nLocal storage contains restaurant data:"
    puts local_storage_data[0..500] + "..."
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  driver&.quit
  puts "\nBrowser closed"
end