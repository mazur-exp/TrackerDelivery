#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"
require "json"

class DebugGrabParser
  TIMEOUT_SECONDS = 20

  def parse(url)
    begin
      Timeout::timeout(TIMEOUT_SECONDS) do
        driver = setup_chrome_driver
        
        puts "=== Navigating to URL: #{url} ==="
        driver.navigate.to url
        
        sleep(3) # Wait for page to load
        
        # Find script tags that contain restaurant data
        scripts = driver.find_elements(:css, "script")
        
        scripts.each_with_index do |script, index|
          content = script.attribute("innerHTML")
          next unless content && content.include?('"props"') && content.include?('ssrRestaurantData')
          
          puts "=== Found restaurant data in script #{index + 1} ==="
          
          # Extract JSON data
          json_start = content.index('{"props"')
          next unless json_start
          
          json_content = content[json_start..-1]
          
          # Find the end of JSON object
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
          
          next unless json_end
          
          json_data = json_content[0..json_end]
          parsed = JSON.parse(json_data)
          
          # Extract restaurant data from parsed JSON
          restaurant_data = parsed.dig('props', 'pageProps', 'ssrRestaurantData')
          next unless restaurant_data
          
          puts "=== Full restaurant data keys: #{restaurant_data.keys} ==="
          
          # Focus on address data
          puts "\n=== ADDRESS INVESTIGATION ==="
          puts "Address field: #{restaurant_data['address'].inspect}"
          
          # Check latlng field too (might contain address info)
          puts "Latlng field: #{restaurant_data['latlng'].inspect}" if restaurant_data['latlng']
          
          # Check section field
          puts "Section field: #{restaurant_data['section'].inspect}" if restaurant_data['section']
          
          # Print all fields that might contain address info
          restaurant_data.each do |key, value|
            if key.to_s.downcase.include?('address') || 
               key.to_s.downcase.include?('location') ||
               key.to_s.downcase.include?('street') ||
               key.to_s.downcase.include?('area') ||
               key.to_s.downcase.include?('district') ||
               key.to_s.downcase.include?('city')
              puts "#{key}: #{value.inspect}"
            end
          end
          
          break # Found the data, exit loop
        end
        
        driver.quit
      end
    rescue Timeout::Error
      puts "Timeout after #{TIMEOUT_SECONDS} seconds"
      driver&.quit
      nil
    rescue => e
      puts "Error: #{e.message}"
      driver&.quit
      nil
    end
  end

  private

  def setup_chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-web-security")
    options.add_argument("--user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1")

    Selenium::WebDriver.for :chrome, options: options
  end
end

# Test the parser
url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
parser = DebugGrabParser.new
parser.parse(url)