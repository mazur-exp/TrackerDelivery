#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'

class TestGojekHttpParser
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
    puts "\n=== Testing GoJek HTTP Parser ==="
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
    doc = Nokogiri::HTML(html_content)
    
    {
      name: extract_restaurant_name_from_html(doc),
      address: extract_address_from_html(doc),
      cuisines: extract_cuisines_from_html(doc),
      rating: extract_rating_from_html(doc),
      image_url: extract_image_url_from_html(doc),
      status: extract_status_from_html(doc)
    }.compact
  end
  
  def extract_restaurant_name_from_html(doc)
    # Same selectors as production parser
    selectors = [
      'h1[data-testid="merchant-name"]',
      "h1.merchant-name", 
      "h1",
      '[data-testid="merchant-name"]',
      ".merchant-name",
      ".restaurant-name",
      "h2.text-gf-content-primary.gf-label-l"
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.strip.length > 3
        puts "Found name with selector #{selector}: '#{element.text.strip}'"
        return element.text.strip
      end
    end
    
    # Try extracting from title tag
    title_element = doc.css('title').first
    if title_element
      title = title_element.text.strip
      # GoJek titles often have format "Restaurant Name | GoFood"
      name = title.split(' | ').first&.strip
      return name if name && name.length > 3
    end
    
    puts "Could not find restaurant name"
    nil
  end
  
  def extract_address_from_html(doc)
    selectors = [
      '[data-testid="merchant-address"]',
      ".merchant-address",
      ".address",
      ".restaurant-address",
      '[class*="address"]'
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      if element && !element.text.strip.empty?
        address = element.text.strip
        puts "Found address with selector #{selector}: '#{address}'"
        return address
      end
    end
    
    # Try meta tags
    meta_address = doc.css('meta[property="og:street-address"]').first&.attribute('content')&.value ||
                   doc.css('meta[name="address"]').first&.attribute('content')&.value
    
    # Try JSON-LD
    json_ld_address = extract_address_from_json_ld(doc)
    
    address = meta_address || json_ld_address
    if address
      puts "Found address in meta/json-ld: '#{address}'"
    else
      puts "Could not find restaurant address"
    end
    
    address
  end
  
  def extract_cuisines_from_html(doc)
    cuisines = []
    
    # Try specific GoJek cuisine selectors
    cuisine_selectors = [
      "p.text-gf-content-secondary.line-clamp-1",
      "p[class*='text-gf-content-secondary']",
      ".cuisine-tags .tag",
      ".categories .category"
    ]
    
    cuisine_selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip
        if text.include?(",") && text.length > 5 && text.length < 100
          # Likely contains cuisine information
          found_cuisines = text.split(/[,•·|&]/).map(&:strip).reject { |x| x.nil? || x.empty? }.first(3)
          if found_cuisines.any?
            puts "Found cuisines with selector #{selector}: #{found_cuisines.join(', ')}"
            cuisines = found_cuisines
            break
          end
        end
      end
      break if cuisines.any?
    end
    
    # Try meta description
    if cuisines.empty?
      meta_desc = doc.css('meta[name="description"]').first&.attribute('content')&.value
      if meta_desc && meta_desc.include?(",")
        potential_cuisines = meta_desc.split(/[,•·|&]/).map(&:strip).reject { |x| x.nil? || x.empty? }
        # Filter out non-cuisine words
        cuisine_words = potential_cuisines.select { |word| 
          word.length > 3 && word.length < 30 && !word.include?("Pesan")
        }.first(3)
        cuisines = cuisine_words if cuisine_words.any?
      end
    end
    
    if cuisines.any?
      puts "Found cuisines: #{cuisines.join(', ')}"
      return cuisines
    else
      puts "Could not find cuisine information"
      return []
    end
  end
  
  def extract_rating_from_html(doc)
    rating_selectors = [
      '[data-testid="rating-value"]',
      ".rating-value",
      ".restaurant-rating .number",
      ".rating-number",
      '[class*="rating"]'
    ]
    
    rating_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        text = element.text.strip
        if text.match?(/^\d+\.?\d*$/) && text.to_f > 0 && text.to_f <= 5
          puts "Found rating with selector #{selector}: '#{text}'"
          return text
        end
      end
    end
    
    # Look for rating in meta tags
    meta_rating = doc.css('meta[property="rating"]').first&.attribute('content')&.value ||
                  doc.css('meta[name="rating"]').first&.attribute('content')&.value
    
    if meta_rating && meta_rating.match?(/^\d+\.?\d*$/)
      puts "Found rating in meta: '#{meta_rating}'"
      return meta_rating
    end
    
    # Look in JSON-LD
    json_ld_rating = extract_rating_from_json_ld(doc)
    if json_ld_rating
      puts "Found rating in JSON-LD: '#{json_ld_rating}'"
      return json_ld_rating.to_s
    end
    
    puts "Could not find rating - might be 'NEW' restaurant"
    "NEW"
  end
  
  def extract_image_url_from_html(doc)
    image_selectors = [
      'img[data-testid="merchant-image"]',
      '.merchant-image img',
      '.restaurant-image img',
      'meta[property="og:image"]'
    ]
    
    image_selectors.each do |selector|
      if selector.include?('meta')
        element = doc.css(selector).first
        if element
          url = element.attribute('content')&.value
          if url && url.start_with?('http')
            puts "Found image URL in meta: '#{url}'"
            return url
          end
        end
      else
        element = doc.css(selector).first
        if element
          url = element.attribute('src')&.value
          if url && url.start_with?('http')
            puts "Found image URL: '#{url}'"
            return url
          end
        end
      end
    end
    
    puts "Could not find restaurant image"
    nil
  end
  
  def extract_status_from_html(doc)
    status_selectors = [
      "div[class*='status']",
      "span[class*='status']",
      "div[class*='tutup']",  # "tutup" = closed in Indonesian
      "div[class*='buka']",   # "buka" = open in Indonesian
      "div[class*='open']",
      "div[class*='close']"
    ]
    
    status_selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip.downcase
        
        # Check Indonesian status words
        if text.include?("tutup") || text.include?("closed")
          return {
            is_open: false,
            status_text: "closed",
            error: nil
          }
        elsif text.include?("buka") || text.include?("open")
          return {
            is_open: true,
            status_text: "open", 
            error: nil
          }
        end
      end
    end
    
    puts "Could not determine status from static HTML"
    {
      is_open: nil,
      status_text: "unknown",
      error: "Status not available in static HTML"
    }
  end
  
  def extract_address_from_json_ld(doc)
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['address'] && !data['address'].empty?
          if data['address'].is_a?(Hash)
            return "#{data['address']['streetAddress']}, #{data['address']['addressLocality']}"
          else
            return data['address']
          end
        end
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  def extract_rating_from_json_ld(doc)
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['aggregateRating'] && !data['aggregateRating'].empty?
          rating = data.dig('aggregateRating', 'ratingValue')
          return rating.to_f if rating && rating.to_f > 0
        end
      rescue JSON::ParserError
        next
      end
    end
    nil
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
                ((data[:address] && !data[:address].empty?) || (data[:rating] && !data[:rating].empty?))
    puts "\nSufficient for onboarding: #{sufficient ? '✓' : '✗'}"
  end
end

# Test URLs (add real GoJek URLs here)
test_urls = [
  # Add real GoJek restaurant URLs for testing
  "https://www.gojek.com/gofood/restaurant/..."
]

if ARGV.length > 0
  # Test single URL from command line
  parser = TestGojekHttpParser.new
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_gojek_http.rb <gojek_url>"
  puts "Example: ruby test_gojek_http.rb 'https://www.gojek.com/gofood/restaurant/...'"
end