#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'

class TestGrabHttpParser
  include HTTParty
  
  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.5',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Connection' => 'keep-alive',
    'Upgrade-Insecure-Requests' => '1'
  })
  
  def initialize
    @timeout = 15
  end
  
  def test_parse(url)
    puts "\n=== Testing Grab HTTP Parser ==="
    puts "URL: #{url}"
    start_time = Time.now
    
    begin
      response = HTTParty.get(url, timeout: @timeout, headers: self.class.headers)
      
      if response.success?
        puts "✓ Successfully fetched page (#{response.body.length} chars)"
        
        data = extract_data_from_html(response.body)
        duration = Time.now - start_time
        
        puts "✓ Parsing completed in #{duration.round(2)}s"
        display_results(data)
        
        return { success: true, data: data, duration: duration }
      else
        puts "✗ HTTP error #{response.code}: #{response.message}"
        return { success: false, error: "HTTP #{response.code}" }
      end
      
    rescue => e
      duration = Time.now - start_time
      puts "✗ Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      return { success: false, error: e.message }
    end
  end
  
  private
  
  def extract_data_from_html(html_content)
    # Try JSON extraction first
    json_data = extract_json_data_from_scripts(html_content)
    return json_data if json_data
    
    # Fallback to DOM parsing
    doc = Nokogiri::HTML(html_content)
    extract_data_from_dom(doc)
  end
  
  def extract_json_data_from_scripts(html_content)
    doc = Nokogiri::HTML(html_content)
    scripts = doc.css('script')
    
    puts "Found #{scripts.count} script tags to analyze"
    
    scripts.each_with_index do |script, index|
      content = script.inner_html
      next if content.nil? || content.empty?
      
      # Same patterns as production parser
      json_patterns = [
        { pattern: '"props".*"ssrRestaurantData"', start: '{"props"' },
        { pattern: '"restaurant".*"name"', start: '{"restaurant"' },
        { pattern: '"pageProps".*"restaurant"', start: '{"pageProps"' }
      ]
      
      json_patterns.each do |pattern_info|
        if content.match(/#{pattern_info[:pattern]}/i)
          puts "Found potential JSON in script #{index + 1}"
          
          json_data = extract_json_from_script_content(content, pattern_info[:start])
          return json_data if json_data
        end
      end
    end
    
    puts "No valid JSON restaurant data found"
    nil
  end
  
  def extract_json_from_script_content(content, start_pattern)
    json_start = content.index(start_pattern)
    return nil unless json_start
    
    json_content = content[json_start..-1]
    
    # Find end of JSON object with proper brace counting
    brace_count = 0
    json_end = nil
    in_string = false
    escape_next = false
    
    json_content.each_char.with_index do |char, i|
      if escape_next
        escape_next = false
        next
      end
      
      if char == '\\'
        escape_next = true
        next
      end
      
      if char == '"' && !escape_next
        in_string = !in_string
        next
      end
      
      next if in_string
      
      case char
      when '{'
        brace_count += 1
      when '}'
        brace_count -= 1
        if brace_count == 0
          json_end = i
          break
        end
      end
    end
    
    return nil unless json_end
    
    json_data = json_content[0..json_end]
    
    begin
      parsed = JSON.parse(json_data)
      puts "Successfully parsed JSON data"
      
      # Extract restaurant data from different possible locations
      restaurant_data = parsed.dig("props", "pageProps", "ssrRestaurantData") ||
                       parsed.dig("restaurant") ||
                       parsed.dig("pageProps", "restaurant")
      
      if restaurant_data
        puts "Found restaurant data with keys: #{restaurant_data.keys.join(', ')}"
        return extract_restaurant_info_from_json(restaurant_data)
      else
        puts "JSON parsed but no restaurant data found"
        return nil
      end
    rescue JSON::ParserError => e
      puts "JSON parsing failed: #{e.message}"
      return nil
    end
  end
  
  def extract_restaurant_info_from_json(restaurant_data)
    # Extract cuisines
    cuisines = []
    if restaurant_data["cuisine"] && !restaurant_data["cuisine"].empty?
      cuisine_text = restaurant_data["cuisine"]
      cuisines = cuisine_text.split(/[,•·|&]/).map(&:strip).reject { |x| x.nil? || x.empty? }.first(3)
    end
    
    # Extract coordinates
    coordinates = nil
    if restaurant_data["latlng"] && !restaurant_data["latlng"].empty?
      coordinates = {
        latitude: restaurant_data["latlng"]["latitude"]&.to_f,
        longitude: restaurant_data["latlng"]["longitude"]&.to_f
      }
    end
    
    # Extract address
    address = restaurant_data["address"] || restaurant_data["shortAddress"]
    
    # Extract rating
    rating = restaurant_data["rating"]&.to_s
    
    {
      name: restaurant_data["name"],
      address: address,
      rating: rating,
      cuisines: cuisines,
      coordinates: coordinates,
      image_url: restaurant_data["photoHref"]
    }.compact
  end
  
  def extract_data_from_dom(doc)
    puts "Falling back to DOM extraction"
    
    # Extract name from title or h1
    name = doc.css('h1').first&.text&.strip ||
           doc.css('title').first&.text&.strip&.split(' | ')&.first
    
    # Look for meta description
    description = doc.css('meta[name="description"]').first&.attribute('content')&.value
    
    {
      name: name,
      address: nil,
      rating: nil,
      cuisines: [],
      coordinates: nil
    }.compact
  end
  
  def display_results(data)
    puts "\n=== Extracted Data ==="
    if data.nil?
      puts "No data extracted"
      return
    end
    
    data.each do |key, value|
      if value.is_a?(Array)
        puts "#{key.capitalize}: #{value.join(', ')}"
      elsif value.is_a?(Hash)
        puts "#{key.capitalize}: #{value}"
      else
        puts "#{key.capitalize}: #{value}"
      end
    end
    
    # Check if sufficient for onboarding
    sufficient = data[:name] && !data[:name].empty? && 
                ((data[:address] && !data[:address].empty?) || data[:coordinates])
    puts "\nSufficient for onboarding: #{sufficient ? '✓' : '✗'}"
  end
end

# Test URLs (add real Grab URLs here)
test_urls = [
  # Add real Grab restaurant URLs for testing
  "https://food.grab.com/id/en/restaurant/..."
]

if ARGV.length > 0
  # Test single URL from command line
  parser = TestGrabHttpParser.new
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_grab_http.rb <grab_url>"
  puts "Example: ruby test_grab_http.rb 'https://food.grab.com/id/en/restaurant/...'"
end