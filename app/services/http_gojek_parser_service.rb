require "httparty"
require "nokogiri"
require "json"

class HttpGojekParserService
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
    Rails.logger.info "=== HTTP GoJek Parser Starting for URL: #{url} ==="
    start_time = Time.current
    
    begin
      response = HTTParty.get(url, timeout: @timeout, headers: self.class.headers)
      
      if response.success?
        Rails.logger.info "HTTP GoJek: Successfully fetched page (#{response.body.length} chars)"
        
        # Try to extract data from HTML
        data = extract_data_from_html(response.body)
        
        duration = Time.current - start_time
        Rails.logger.info "HTTP GoJek: Parsing completed in #{duration.round(2)}s"
        
        return data
      else
        Rails.logger.error "HTTP GoJek: HTTP error #{response.code}: #{response.message}"
        return nil
      end
      
    rescue => e
      duration = Time.current - start_time
      Rails.logger.error "HTTP GoJek: Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      return nil
    end
  end
  
  private
  
  def extract_data_from_html(html_content)
    doc = Nokogiri::HTML(html_content)
    
    # Extract data using same selectors as Chrome version
    {
      name: extract_restaurant_name_from_html(doc),
      address: extract_address_from_html(doc),
      cuisines: extract_cuisines_from_html(doc),
      rating: extract_rating_from_html(doc),
      working_hours: extract_working_hours_from_html(doc),
      image_url: extract_image_url_from_html(doc),
      status: extract_status_from_html(doc)
    }.compact
  end
  
  def extract_restaurant_name_from_html(doc)
    # Same selectors as Chrome version
    selectors = [
      'h1[data-testid="merchant-name"]',
      "h1.merchant-name", 
      "h1",
      '[data-testid="merchant-name"]',
      ".merchant-name",
      ".restaurant-name",
      # Additional selectors for modal titles
      "h2.text-gf-content-primary.gf-label-l"
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.strip.present? && element.text.strip.length > 3
        Rails.logger.info "HTTP GoJek: Found name with selector #{selector}: '#{element.text.strip}'"
        return element.text.strip
      end
    end
    
    # Try extracting from title tag
    title_element = doc.css('title').first
    if title_element
      title = title_element.text.strip
      # GoJek titles often have format "Restaurant Name | GoFood"
      name = title.split(' | ').first&.strip
      return name if name.present? && name.length > 3
    end
    
    Rails.logger.warn "HTTP GoJek: Could not find restaurant name"
    nil
  end
  
  def extract_address_from_html(doc)
    # Same selectors as Chrome version
    selectors = [
      '[data-testid="merchant-address"]',
      ".merchant-address",
      ".address",
      ".restaurant-address",
      '[class*="address"]'
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.strip.present?
        address = element.text.strip
        Rails.logger.info "HTTP GoJek: Found address with selector #{selector}: '#{address}'"
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
      Rails.logger.info "HTTP GoJek: Found address in meta/json-ld: '#{address}'"
    else
      Rails.logger.warn "HTTP GoJek: Could not find restaurant address"
    end
    
    address
  end
  
  def extract_cuisines_from_html(doc)
    # Look for cuisine information in various places
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
          found_cuisines = text.split(/[,•·|&]/).map(&:strip).reject(&:blank?).first(3)
          if found_cuisines.any?
            Rails.logger.info "HTTP GoJek: Found cuisines with selector #{selector}: #{found_cuisines.join(', ')}"
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
        potential_cuisines = meta_desc.split(/[,•·|&]/).map(&:strip).reject(&:blank?)
        # Filter out non-cuisine words
        cuisine_words = potential_cuisines.select { |word| 
          word.length > 3 && word.length < 30 && !word.include?("Pesan")
        }.first(3)
        cuisines = cuisine_words if cuisine_words.any?
      end
    end
    
    # Translate Indonesian cuisines to English
    if cuisines.any?
      begin
        translated_cuisines = cuisines.map { |cuisine| 
          CuisineTranslationService.translate(cuisine) 
        }
        Rails.logger.info "HTTP GoJek: Translated cuisines: #{translated_cuisines.join(', ')}"
        return translated_cuisines
      rescue => e
        Rails.logger.warn "HTTP GoJek: Error translating cuisines: #{e.message}"
        return cuisines
      end
    else
      Rails.logger.warn "HTTP GoJek: Could not find cuisine information"
      return []
    end
  end
  
  def extract_rating_from_html(doc)
    # Look for rating information
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
          Rails.logger.info "HTTP GoJek: Found rating with selector #{selector}: '#{text}'"
          return text
        end
      end
    end
    
    # Look for rating in meta tags
    meta_rating = doc.css('meta[property="rating"]').first&.attribute('content')&.value ||
                  doc.css('meta[name="rating"]').first&.attribute('content')&.value
    
    if meta_rating && meta_rating.match?(/^\d+\.?\d*$/)
      Rails.logger.info "HTTP GoJek: Found rating in meta: '#{meta_rating}'"
      return meta_rating
    end
    
    # Look in JSON-LD
    json_ld_rating = extract_rating_from_json_ld(doc)
    if json_ld_rating
      Rails.logger.info "HTTP GoJek: Found rating in JSON-LD: '#{json_ld_rating}'"
      return json_ld_rating.to_s
    end
    
    Rails.logger.warn "HTTP GoJek: Could not find rating - might be 'NEW' restaurant"
    "NEW"  # Default for new restaurants
  end
  
  def extract_working_hours_from_html(doc)
    # This is complex in GoJek as hours are often in modals
    # For HTTP version, we'll try to find basic hours info
    
    hours_selectors = [
      '[data-testid="operating-hours"]',
      ".operating-hours",
      ".working-hours", 
      ".hours",
      '[class*="hours"]'
    ]
    
    hours_selectors.each do |selector|
      elements = doc.css(selector)
      if elements.any?
        # Try to parse hours text
        hours_text = elements.map(&:text).join(" ").strip
        if hours_text.present? && hours_text.length > 10
          Rails.logger.info "HTTP GoJek: Found hours text: '#{hours_text}'"
          # This would need complex parsing - simplified for now
          return []  # Return empty for now, full parsing is complex without modal
        end
      end
    end
    
    Rails.logger.warn "HTTP GoJek: Could not extract working hours from static HTML"
    []  # Working hours often require modal interaction
  end
  
  def extract_image_url_from_html(doc)
    # Look for restaurant images
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
            Rails.logger.info "HTTP GoJek: Found image URL in meta: '#{url}'"
            return url
          end
        end
      else
        element = doc.css(selector).first
        if element
          url = element.attribute('src')&.value
          if url && url.start_with?('http')
            Rails.logger.info "HTTP GoJek: Found image URL: '#{url}'"
            return url
          end
        end
      end
    end
    
    Rails.logger.warn "HTTP GoJek: Could not find restaurant image"
    nil
  end
  
  def extract_status_from_html(doc)
    # Look for status indicators
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
    
    Rails.logger.warn "HTTP GoJek: Could not determine status from static HTML"
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
    nil
  end
  
  def extract_rating_from_json_ld(doc)
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['aggregateRating'].present?
          rating = data.dig('aggregateRating', 'ratingValue')
          return rating.to_f if rating && rating.to_f > 0
        end
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  # Method to check if extracted data is sufficient for onboarding
  def sufficient_for_onboarding?(data)
    return false unless data.is_a?(Hash)
    
    data[:name].present? && 
    (data[:address].present? || data[:rating].present?)
  end
end