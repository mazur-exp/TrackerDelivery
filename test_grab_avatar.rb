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

# Test finding restaurant avatar specifically
test_url = "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "Looking for restaurant avatar on Grab page:"
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
  
  # Look in the header/hero section
  puts "\n--- Checking header/hero sections ---"
  header_selectors = [
    ".header",
    ".hero", 
    ".merchant-header",
    ".restaurant-header",
    "[class*='header']",
    "[class*='hero']",
    "[class*='merchant']",
    "[class*='restaurant']"
  ]
  
  header_selectors.each do |selector|
    begin
      elements = driver.find_elements(:css, selector)
      elements.each_with_index do |element, idx|
        class_name = element.attribute("class")
        puts "\nFound #{selector} element #{idx + 1}: #{class_name}"
        
        # Look for images within this element
        imgs_in_element = element.find_elements(:css, "img")
        imgs_in_element.each_with_index do |img, img_idx|
          src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
          alt = img.attribute("alt")
          img_class = img.attribute("class")
          
          if src.present?
            puts "  Image #{img_idx + 1}: #{src}"
            puts "  Alt: #{alt}" if alt.present?
            puts "  Class: #{img_class}" if img_class.present?
            
            # Check if it's not a menu item
            if !src.include?('/items/') && !src.include?('plus-white.svg') && !src.include?('logo')
              puts "  👆 POTENTIAL AVATAR (not menu item)"
            end
          end
        end
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Continue
    end
  end
  
  # Look for background images in CSS
  puts "\n--- Checking for background images ---"
  elements_with_style = driver.find_elements(:css, "[style*='background']")
  elements_with_style.each_with_index do |element, idx|
    style = element.attribute("style")
    if style.include?('background-image') && style.include?('url(')
      puts "Background image #{idx + 1}: #{style}"
      # Extract URL from background-image: url(...)
      url_match = style.match(/url\(['"]?([^'")\s]+)['"]?\)/)
      if url_match
        bg_url = url_match[1]
        puts "  Extracted URL: #{bg_url}"
        if !bg_url.include?('/items/') && !bg_url.include?('logo')
          puts "  👆 POTENTIAL AVATAR BACKGROUND"
        end
      end
    end
  end
  
  # Look for specific merchant/restaurant image classes or IDs
  puts "\n--- Checking specific merchant image patterns ---"
  merchant_image_selectors = [
    "img[alt*='Prana Kitchen']",
    "img[alt*='restaurant']",
    "img[alt*='merchant']",
    "[class*='merchant'][class*='image'] img",
    "[class*='restaurant'][class*='image'] img",
    "[class*='merchant'][class*='photo'] img",
    "[class*='merchant'][class*='avatar'] img",
    "[id*='merchant'] img",
    "[id*='restaurant'] img"
  ]
  
  merchant_image_selectors.each do |selector|
    begin
      images = driver.find_elements(:css, selector)
      images.each_with_index do |img, idx|
        src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
        alt = img.attribute("alt")
        img_class = img.attribute("class")
        
        if src.present?
          puts "\nMerchant image (#{selector}) #{idx + 1}:"
          puts "  SRC: #{src}"
          puts "  ALT: #{alt}" if alt.present?
          puts "  CLASS: #{img_class}" if img_class.present?
        end
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Continue
    end
  end
  
  # Check if there are different image URLs in the JSON data we missed
  puts "\n--- Double checking JSON for all image URLs ---"
  scripts = driver.find_elements(:css, "script")
  scripts.each do |script|
    content = script.attribute("innerHTML")
    next unless content && content.include?('"props"')
    
    # Look for any URLs that end with image extensions
    urls = content.scan(/https?:\/\/[^\s"']+\.(?:jpg|jpeg|png|gif|webp)/i)
    
    if urls.any?
      puts "\nFound image URLs in JSON:"
      urls.uniq.each do |url|
        puts "  #{url}"
        if url.include?('merchant') && !url.include?('/items/')
          puts "    👆 POTENTIAL MERCHANT IMAGE"
        end
      end
    end
    
    break if urls.any?
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  driver&.quit
  puts "\nBrowser closed"
end