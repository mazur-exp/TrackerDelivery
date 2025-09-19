#!/usr/bin/env ruby

# Mock Rails logger for testing
class MockLogger
  def info(message)
    puts "[INFO] #{message}"
  end
  
  def error(message)
    puts "[ERROR] #{message}"
  end
  
  def warn(message)
    puts "[WARN] #{message}"
  end
end

module Rails
  def self.logger
    @logger ||= MockLogger.new
  end
end

# Mock ActiveSupport methods
class String
  def blank?
    self.nil? || self.strip.empty?
  end
  
  def present?
    !blank?
  end
end

class NilClass
  def blank?
    true
  end
  
  def present?
    false
  end
end

require "selenium-webdriver"
require "json"

# Test different image sources on Grab page
test_url = "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "Finding all images on Grab page:"
puts "=" * 80

driver = nil
begin
  # Setup Chrome
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1920,1080")
  options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
  
  puts "Starting Chrome..."
  driver = Selenium::WebDriver.for(:chrome, options: options)
  
  puts "Navigating to URL..."
  driver.get(test_url)
  sleep(3)
  
  current_url = driver.current_url
  puts "Current URL: #{current_url}"
  
  # Find all images on the page
  images = driver.find_elements(:css, "img")
  puts "\nFound #{images.length} images on the page:"
  
  images.each_with_index do |img, index|
    src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
    alt = img.attribute("alt")
    class_name = img.attribute("class")
    
    if src.present?
      puts "\n--- Image #{index + 1} ---"
      puts "SRC: #{src}"
      puts "ALT: #{alt}" if alt.present?
      puts "CLASS: #{class_name}" if class_name.present?
      
      # Check if it looks like restaurant/merchant image
      if src.include?('merchant') || src.include?('restaurant') || alt.to_s.downcase.include?('restaurant') || alt.to_s.downcase.include?('merchant')
        puts "👆 POTENTIAL RESTAURANT IMAGE"
      end
      
      # Check different image formats
      if src.include?('.webp')
        puts "Format: WebP"
      elsif src.include?('.jpg') || src.include?('.jpeg')
        puts "Format: JPEG"
      elsif src.include?('.png')
        puts "Format: PNG"
      end
    end
  end
  
  # Also check JSON data for more image URLs
  puts "\n" + "=" * 50
  puts "Checking JSON data for image URLs:"
  
  scripts = driver.find_elements(:css, "script")
  scripts.each do |script|
    content = script.attribute("innerHTML")
    next unless content && content.include?('"props"') && content.include?('ssrRestaurantData')
    
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
    
    restaurant_data = parsed.dig('props', 'pageProps', 'ssrRestaurantData')
    next unless restaurant_data
    
    puts "\nJSON Image URLs found:"
    restaurant_data.each do |key, value|
      if key.to_s.downcase.include?('photo') || key.to_s.downcase.include?('image') || key.to_s.downcase.include?('href')
        puts "#{key}: #{value}"
      elsif value.is_a?(String) && (value.include?('http') && (value.include?('.jpg') || value.include?('.png') || value.include?('.webp')))
        puts "#{key}: #{value}"
      end
    end
    
    # Look for menu images or other image arrays
    if restaurant_data['menu']
      puts "\nChecking menu for images..."
      menu_data = restaurant_data['menu']
      if menu_data.is_a?(Hash)
        menu_data.each do |menu_key, menu_value|
          if menu_value.is_a?(Array)
            menu_value.each_with_index do |item, idx|
              if item.is_a?(Hash) && item['photoHref']
                puts "Menu item #{idx} image: #{item['photoHref']}"
              end
            end
          end
        end
      end
    end
    
    break
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  driver&.quit
  puts "\nBrowser closed"
end