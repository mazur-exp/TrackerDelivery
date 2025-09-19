#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"

class DebugGrabDomParser
  TIMEOUT_SECONDS = 20

  def parse(url)
    begin
      Timeout::timeout(TIMEOUT_SECONDS) do
        driver = setup_chrome_driver
        
        puts "=== Navigating to URL: #{url} ==="
        driver.navigate.to url
        
        sleep(3) # Wait for page to load
        
        puts "\n=== SEARCHING FOR ADDRESS IN DOM ==="
        
        # Search for text containing "Jl. Raya Padonan"
        puts "Searching for 'Jl. Raya Padonan'..."
        
        begin
          # Try to find elements containing the address
          elements = driver.find_elements(:xpath, "//*[contains(text(), 'Jl. Raya Padonan')]")
          puts "Found #{elements.length} elements containing 'Jl. Raya Padonan'"
          
          elements.each_with_index do |element, index|
            puts "Element #{index + 1}: #{element.text}"
            puts "Tag: #{element.tag_name}, Class: #{element.attribute('class')}"
          end
        rescue => e
          puts "Error searching for 'Jl. Raya Padonan': #{e.message}"
        end
        
        # Try broader search for "Padonan"
        puts "\nSearching for 'Padonan'..."
        begin
          elements = driver.find_elements(:xpath, "//*[contains(text(), 'Padonan')]")
          puts "Found #{elements.length} elements containing 'Padonan'"
          
          elements.each_with_index do |element, index|
            puts "Element #{index + 1}: #{element.text}"
            puts "Tag: #{element.tag_name}, Class: #{element.attribute('class')}"
          end
        rescue => e
          puts "Error searching for 'Padonan': #{e.message}"
        end
        
        # Try to find common address patterns
        puts "\n=== SEARCHING FOR ADDRESS PATTERNS ==="
        
        address_selectors = [
          "//div[contains(@class, 'address')]",
          "//span[contains(@class, 'address')]", 
          "//p[contains(@class, 'address')]",
          "//*[contains(@class, 'location')]",
          "//*[contains(@class, 'street')]",
          "//*[contains(text(), 'Jl.')]",
          "//*[contains(text(), 'Street')]",
          "//*[contains(text(), 'Tibubeneng')]"
        ]
        
        address_selectors.each do |selector|
          begin
            elements = driver.find_elements(:xpath, selector)
            if elements.length > 0
              puts "Selector '#{selector}' found #{elements.length} elements:"
              elements.first(3).each_with_index do |element, index|
                puts "  #{index + 1}: #{element.text.strip}"
              end
            end
          rescue => e
            puts "Error with selector '#{selector}': #{e.message}"
          end
        end
        
        # Print page title and check if we're on the right page
        puts "\n=== PAGE INFO ==="
        puts "Page title: #{driver.title}"
        puts "Current URL: #{driver.current_url}"
        puts "Page source length: #{driver.page_source.length} characters"
        
        # Save page source to file for debugging
        File.write('/tmp/grab_page_source.html', driver.page_source)
        puts "Page source saved to /tmp/grab_page_source.html"
        
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
parser = DebugGrabDomParser.new
parser.parse(url)