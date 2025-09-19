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

# Test both restaurants for open/closed status
restaurants = [
  {
    name: "Prana Kitchen",
    url: "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  },
  {
    name: "Bright Coffee", 
    url: "https://r.grab.com/g/6-20250919_181803_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C7BJC6A3CRMZNT"
  }
]

restaurants.each do |restaurant|
  puts "\n" + "=" * 80
  puts "CHECKING STATUS: #{restaurant[:name]}"
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
    
    puts "Starting Chrome for #{restaurant[:name]}..."
    driver = Selenium::WebDriver.for(:chrome, options: options)
    
    puts "Navigating to URL..."
    driver.get(restaurant[:url])
    sleep(3)
    
    current_url = driver.current_url
    puts "Current URL: #{current_url}"
    
    # Look for status indicators in text
    puts "\n--- Checking for status text ---"
    status_keywords = ["open", "closed", "tutup", "buka", "unavailable", "available", "temporarily closed"]
    
    status_keywords.each do |keyword|
      elements = driver.find_elements(:css, "*")
      found_elements = elements.select do |element|
        text = element.text.strip.downcase rescue ""
        text.include?(keyword.downcase)
      end
      
      if found_elements.any?
        puts "\nFound '#{keyword}' in #{found_elements.length} elements:"
        found_elements.first(3).each_with_index do |element, idx|
          text = element.text.strip rescue ""
          next if text.length > 200 # Skip very long text
          puts "  #{idx + 1}. #{text}" if text.present?
        end
      end
    end
    
    # Check JSON data for status
    puts "\n--- Checking JSON for status ---"
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
      
      puts "\nJSON Status-related fields:"
      restaurant_data.each do |key, value|
        if key.to_s.downcase.include?('status') || key.to_s.downcase.include?('open') || key.to_s.downcase.include?('available')
          puts "#{key}: #{value}"
        elsif key == 'openingHours' && value.is_a?(Hash)
          puts "openingHours.open: #{value['open']}" if value.key?('open')
          puts "openingHours.displayedHours: #{value['displayedHours']}" if value.key?('displayedHours')
        end
      end
      
      break
    end
    
    # Check page title for status info
    title = driver.title
    puts "\nPage title: #{title}"
    if title.downcase.include?('closed') || title.downcase.include?('tutup')
      puts "👆 STATUS INDICATOR IN TITLE"
    end

  rescue => e
    puts "Error: #{e.message}"
  ensure
    driver&.quit
    puts "Browser closed for #{restaurant[:name]}"
  end
end