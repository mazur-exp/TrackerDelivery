#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"
require "json"

class DebugGrabMapParser
  TIMEOUT_SECONDS = 20

  def parse(url)
    begin
      Timeout::timeout(TIMEOUT_SECONDS) do
        driver = setup_chrome_driver
        
        puts "=== Navigating to URL: #{url} ==="
        driver.navigate.to url
        
        sleep(3) # Wait for page to load
        
        puts "\n=== SEARCHING FOR MAP-RELATED DATA ==="
        
        # 1. Search in JSON for map-related fields
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
          
          # Look for map-related data in the entire JSON
          puts "\n=== SEARCHING FOR MAP/LOCATION DATA IN JSON ==="
          search_for_map_data(parsed, "")
          
          break # Found the data, exit loop
        end
        
        # 2. Search for map-related elements in DOM
        puts "\n=== SEARCHING FOR MAP ELEMENTS IN DOM ==="
        
        map_selectors = [
          "//div[contains(@class, 'map')]",
          "//div[contains(@id, 'map')]", 
          "//*[contains(@class, 'grab-map')]",
          "//*[contains(@class, 'location')]",
          "//*[contains(@class, 'coordinates')]",
          "//*[contains(@data-lat, '')]",
          "//*[contains(@data-lng, '')]",
          "//*[@data-latitude]",
          "//*[@data-longitude]"
        ]
        
        map_selectors.each do |selector|
          begin
            elements = driver.find_elements(:xpath, selector)
            if elements.length > 0
              puts "Map selector '#{selector}' found #{elements.length} elements:"
              elements.first(2).each_with_index do |element, index|
                puts "  #{index + 1}: Tag=#{element.tag_name}, Text=#{element.text.strip[0..100]}"
                puts "      Class=#{element.attribute('class')}"
                puts "      ID=#{element.attribute('id')}"
                
                # Check for data attributes that might contain coordinates or address
                %w[data-lat data-lng data-latitude data-longitude data-address data-location].each do |attr|
                  value = element.attribute(attr)
                  puts "      #{attr}=#{value}" if value && !value.empty?
                end
              end
            end
          rescue => e
            puts "Error with selector '#{selector}': #{e.message}"
          end
        end
        
        # 3. Search for network requests or APIs
        puts "\n=== SEARCHING FOR MAP API CALLS ==="
        
        # Look for any script tags that might contain map initialization
        map_scripts = driver.find_elements(:css, "script")
        map_scripts.each_with_index do |script, index|
          content = script.attribute("innerHTML")
          next unless content
          
          if content.include?('map') || content.include?('Map') || 
             content.include?('latitude') || content.include?('longitude') ||
             content.include?('grab') && (content.include?('map') || content.include?('location'))
            
            puts "Script #{index + 1} contains map-related code:"
            # Show relevant parts
            lines = content.split("\n")
            lines.each_with_index do |line, line_index|
              if line.downcase.include?('map') || line.include?('latitude') || 
                 line.include?('longitude') || line.include?('address')
                puts "  Line #{line_index + 1}: #{line.strip[0..150]}"
              end
            end
          end
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

  def search_for_map_data(data, path = "", max_depth = 5)
    return if max_depth <= 0
    
    case data
    when Hash
      data.each do |key, value|
        current_path = path.empty? ? key : "#{path}.#{key}"
        
        # Check if key suggests map/location data
        if key.to_s.downcase.match?(/map|location|address|street|area|district|coordinates|lat|lng|geo/)
          puts "#{current_path}: #{value.inspect}"
        end
        
        search_for_map_data(value, current_path, max_depth - 1)
      end
    when Array
      data.each_with_index do |item, index|
        current_path = "#{path}[#{index}]"
        search_for_map_data(item, current_path, max_depth - 1)
      end
    when String
      # Check if string contains coordinates or address-like data
      if data.match?(/[-+]?\d*\.?\d+,\s*[-+]?\d*\.?\d+/) || # coordinates pattern
         data.include?('Jl.') || data.include?('Street') || 
         data.include?('Tibubeneng') || data.include?('Padonan')
        puts "#{path} (string): #{data}"
      end
    end
  end

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
parser = DebugGrabMapParser.new
parser.parse(url)