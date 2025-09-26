require "httparty"
require "nokogiri"
require "json"

class HttpGrabParserService
  include HTTParty
  
  # Use browser-like headers to avoid blocking
  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.5',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Connection' => 'keep-alive',
    'Upgrade-Insecure-Requests' => '1'
  })
  
  def initialize
    @timeout = 15  # Much faster than Chrome
  end
  
  def parse(url)
    Rails.logger.info "=== HTTP Grab Parser Starting for URL: #{url} ==="
    start_time = Time.current
    
    begin
      response = HTTParty.get(url, timeout: @timeout, headers: self.class.headers)
      
      if response.success?
        Rails.logger.info "HTTP Grab: Successfully fetched page (#{response.body.length} chars)"
        
        # Try to extract data from HTML
        data = extract_data_from_html(response.body)
        
        duration = Time.current - start_time
        Rails.logger.info "HTTP Grab: Parsing completed in #{duration.round(2)}s"
        
        return data
      else
        Rails.logger.error "HTTP Grab: HTTP error #{response.code}: #{response.message}"
        return nil
      end
      
    rescue => e
      duration = Time.current - start_time
      Rails.logger.error "HTTP Grab: Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      return nil
    end
  end
  
  private
  
  def extract_data_from_html(html_content)
    doc = Nokogiri::HTML(html_content)
    
    # Try JSON extraction first (same logic as Chrome version)
    json_data = extract_json_data_from_scripts(html_content)
    return json_data if json_data
    
    # Fallback to DOM parsing
    extract_data_from_dom(doc)
  end
  
  def extract_json_data_from_scripts(html_content)
    # Find all script tags
    doc = Nokogiri::HTML(html_content)
    scripts = doc.css('script')
    
    Rails.logger.info "HTTP Grab: Found #{scripts.count} script tags to analyze"
    
    scripts.each_with_index do |script, index|
      content = script.inner_html
      next unless content.present?
      
      # Same patterns as in Chrome version
      json_patterns = [
        { pattern: '"props".*"ssrRestaurantData"', start: '{"props"' },
        { pattern: '"restaurant".*"name"', start: '{"restaurant"' },
        { pattern: '"pageProps".*"restaurant"', start: '{"pageProps"' }
      ]
      
      json_patterns.each do |pattern_info|
        if content.match(/#{pattern_info[:pattern]}/i)
          Rails.logger.info "HTTP Grab: Found potential JSON in script #{index + 1}"
          
          json_data = extract_json_from_script_content(content, pattern_info[:start])
          return json_data if json_data
        end
      end
    end
    
    Rails.logger.warn "HTTP Grab: No valid JSON restaurant data found"
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
      Rails.logger.info "HTTP Grab: Successfully parsed JSON data"
      
      # Extract restaurant data from different possible locations
      restaurant_data = parsed.dig("props", "pageProps", "ssrRestaurantData") ||
                       parsed.dig("restaurant") ||
                       parsed.dig("pageProps", "restaurant")
      
      if restaurant_data
        Rails.logger.info "HTTP Grab: Found restaurant data with keys: #{restaurant_data.keys.join(', ')}"
        return extract_restaurant_info_from_json(restaurant_data)
      else
        Rails.logger.warn "HTTP Grab: JSON parsed but no restaurant data found"
        return nil
      end
    rescue JSON::ParserError => e
      Rails.logger.warn "HTTP Grab: JSON parsing failed: #{e.message}"
      return nil
    end
  end
  
  def extract_restaurant_info_from_json(restaurant_data)
    # Same extraction logic as Chrome version
    cuisines = []
    if restaurant_data["cuisine"].present?
      cuisine_text = restaurant_data["cuisine"]
      cuisines = cuisine_text.split(/[,•·|&]/).map(&:strip).reject(&:blank?).first(3)
    end
    
    # Extract coordinates
    coordinates = nil
    if restaurant_data["latlng"].present?
      coordinates = {
        latitude: restaurant_data["latlng"]["latitude"]&.to_f,
        longitude: restaurant_data["latlng"]["longitude"]&.to_f
      }
    end
    
    # Extract address
    address = restaurant_data["address"] || restaurant_data["shortAddress"]
    
    # Extract rating
    rating = restaurant_data["rating"]&.to_s
    
    # Extract status (if available)
    status = extract_status_from_json(restaurant_data)
    
    {
      name: restaurant_data["name"],
      address: address,
      rating: rating,
      cuisines: cuisines,
      coordinates: coordinates,
      status: status,
      image_url: restaurant_data["photoHref"]
    }.compact
  end
  
  def extract_status_from_json(restaurant_data)
    # Try to determine status from JSON data
    # This might not always be available in static JSON
    if restaurant_data["isOpen"].present?
      {
        is_open: restaurant_data["isOpen"],
        status_text: restaurant_data["isOpen"] ? "open" : "closed",
        error: nil
      }
    else
      # Status might not be available in static HTML
      {
        is_open: nil,
        status_text: "unknown",
        error: "Status not available in static data"
      }
    end
  end
  
  def extract_data_from_dom(doc)
    # Fallback DOM extraction if JSON fails
    Rails.logger.info "HTTP Grab: Falling back to DOM extraction"
    
    # Extract name from title or h1
    name = doc.css('h1').first&.text&.strip ||
           doc.css('title').first&.text&.strip&.split(' | ')&.first
    
    # Look for meta description or other meta tags
    description = doc.css('meta[name="description"]').first&.attribute('content')&.value
    
    # Try to extract address from meta or structured data
    address = extract_address_from_meta(doc)
    
    {
      name: name,
      address: address,
      rating: nil,
      cuisines: [],
      coordinates: nil,
      status: { is_open: nil, status_text: "unknown", error: "Limited data from DOM" }
    }.compact
  end
  
  def extract_address_from_meta(doc)
    # Look for address in various meta tags or structured data
    meta_address = doc.css('meta[property="og:street-address"]').first&.attribute('content')&.value ||
                   doc.css('meta[name="address"]').first&.attribute('content')&.value
    
    # Look for JSON-LD structured data
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['address'].present?
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
    
    meta_address
  end
  
  # Method to check if extracted data is sufficient for onboarding
  def sufficient_for_onboarding?(data)
    return false unless data.is_a?(Hash)
    
    data[:name].present? && 
    (data[:address].present? || data[:coordinates].present?)
  end
end