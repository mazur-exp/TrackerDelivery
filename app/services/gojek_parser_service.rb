require "nokogiri"
require "open-uri"
require "timeout"

class GojekParserService
  TIMEOUT_SECONDS = 10

  def parse(url)
    return nil if url.blank?

    begin
      Timeout.timeout(TIMEOUT_SECONDS) do
        # Fetch the page
        page = fetch_page(url)
        return nil unless page

        doc = Nokogiri::HTML(page)

        # Extract data from the page
        {
          name: extract_restaurant_name(doc),
          address: extract_address(doc),
          cuisines: extract_cuisines(doc),
          working_hours: extract_working_hours(doc),
          rating: extract_rating(doc),
          image_url: extract_image_url(doc)
        }
      end
    rescue Timeout::Error
      Rails.logger.error "Timeout while parsing GoJek URL: #{url}"
      nil
    rescue => e
      Rails.logger.error "Error parsing GoJek URL #{url}: #{e.message}"
      nil
    end
  end

  private

  def fetch_page(url)
    # Add user agent to avoid blocking
    headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.5",
      "Accept-Encoding" => "gzip, deflate, br",
      "DNT" => "1",
      "Connection" => "keep-alive",
      "Upgrade-Insecure-Requests" => "1"
    }

    begin
      Rails.logger.info "Fetching GoJek page: #{url}"
      content = URI.open(url, headers).read
      Rails.logger.info "Successfully fetched GoJek page, size: #{content.length} bytes"
      content
    rescue => e
      Rails.logger.error "Failed to fetch GoJek page #{url}: #{e.class} - #{e.message}"
      nil
    end
  end

  def extract_restaurant_name(doc)
    # Try multiple selectors for restaurant name
    selectors = [
      'h1[data-testid="merchant-name"]',
      "h1.merchant-name",
      "h1",
      '[data-testid="merchant-name"]',
      ".merchant-name",
      ".restaurant-name"
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.present?
        return element.text.strip
      end
    end

    # Fallback: try to extract from title
    title = doc.css("title").first
    if title && title.text.present?
      # GoFood titles often have format "Restaurant Name | GoFood"
      name = title.text.split("|").first&.strip
      return name if name.present? && name.length > 3
    end

    nil
  end

  def extract_address(doc)
    # Try multiple selectors for address
    selectors = [
      '[data-testid="merchant-address"]',
      ".merchant-address",
      ".address",
      ".restaurant-address",
      '[class*="address"]'
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.present?
        address = element.text.strip
        return address if address.length > 10 # Reasonable address length
      end
    end

    nil
  end

  def extract_cuisines(doc)
    cuisines = []

    # Look for font elements with dir="auto" that contain comma-separated text
    doc.css('font[dir="auto"]').each do |font|
      text = font.text.strip
      
      # Check if it looks like cuisine text (contains commas, reasonable length)
      if text.include?(',') && text.length > 5 && text.length < 100
        # Skip if it looks like a restaurant name
        next if text.downcase.include?('only eggs') || text.downcase.include?('restaurant')
        
        # Split by commas and clean up
        text.split(',').each do |cuisine|
          cleaned = cuisine.strip
          if cleaned.present? && cleaned.length < 30
            cuisines << cleaned
          end
        end
        
        break if cuisines.any?
      end
    end
    
    # If no cuisines found, try broader search
    if cuisines.empty?
      doc.css('p, div, span').each do |element|
        text = element.text.strip
        
        # Look for text that might be cuisines
        if text.match?(/^[A-Za-z\s,]+$/) && text.include?(',') && 
           text.length > 10 && text.length < 50 &&
           !text.downcase.include?('only eggs') &&
           !text.downcase.include?('restaurant')
          
          text.split(',').each do |cuisine|
            cleaned = cuisine.strip
            cuisines << cleaned if cleaned.present?
          end
          
          break if cuisines.any?
        end
      end
    end

    # Clean and deduplicate cuisines
    cuisines.map(&:strip).uniq.reject(&:blank?).first(3)
  end

  def extract_rating(doc)
    # Look for any p tag with gf-label classes that contains a number
    doc.css('p').each do |p|
      class_attr = p['class'].to_s
      text = p.text.strip
      
      # Check if it has gf-label classes and contains only a number
      if class_attr.include?('gf-label') && text.match?(/^\d+(\.\d+)?$/)
        rating = text.to_f
        return rating if rating >= 1.0 && rating <= 5.0
      end
    end
    
    # Fallback: look for any element with rating-like text
    doc.css('*').each do |element|
      text = element.text.strip
      # Look for standalone numbers that could be ratings
      if text.match?(/^[1-5](\.\d)?$/) && element.children.length == 1
        rating = text.to_f
        return rating if rating >= 1.0 && rating <= 5.0
      end
    end

    nil
  end

  def extract_working_hours(doc)
    working_hours = []

    # Try to find working hours section
    selectors = [
      '[data-testid="operating-hours"]',
      ".operating-hours",
      ".working-hours",
      ".hours",
      '[class*="hours"]'
    ]

    selectors.each do |selector|
      elements = doc.css(selector)
      if elements.any?
        working_hours = parse_working_hours_from_elements(elements)
        break if working_hours.any?
      end
    end

    working_hours
  end

  def parse_working_hours_from_elements(elements)
    hours = []

    elements.each do |element|
      text = element.text.strip

      # Try to parse day and time patterns
      # Examples: "Monday: 09:00 - 22:00", "Mon-Fri: 9AM-10PM", etc.
      lines = text.split(/\n|;/).map(&:strip).reject(&:blank?)

      lines.each do |line|
        day_hours = parse_single_day_hours(line)
        hours.concat(day_hours) if day_hours.any?
      end
    end

    hours
  end

  def parse_single_day_hours(line)
    # Basic parsing for now - can be enhanced
    # Patterns: "Monday: 09:00 - 22:00", "Mon-Fri: 9:00-22:00", etc.

    return [] unless line.include?(":")

    parts = line.split(":", 2)
    day_part = parts[0].strip
    time_part = parts[1].strip

    days = parse_day_range(day_part)
    times = parse_time_range(time_part)

    return [] if days.empty? || times.empty?

    days.map do |day_num|
      {
        day_of_week: day_num,
        opens_at: times[:opens_at],
        closes_at: times[:closes_at],
        is_closed: times[:is_closed] || false
      }
    end
  end

  def parse_day_range(day_text)
    day_mapping = {
      "monday" => 0, "mon" => 0,
      "tuesday" => 1, "tue" => 1, "tues" => 1,
      "wednesday" => 2, "wed" => 2,
      "thursday" => 3, "thu" => 3, "thurs" => 3,
      "friday" => 4, "fri" => 4,
      "saturday" => 5, "sat" => 5,
      "sunday" => 6, "sun" => 6
    }

    normalized = day_text.downcase.strip

    # Check for range (e.g., "Mon-Fri")
    if normalized.include?("-")
      parts = normalized.split("-", 2).map(&:strip)
      start_day = day_mapping[parts[0]]
      end_day = day_mapping[parts[1]]

      if start_day && end_day
        if start_day <= end_day
          return (start_day..end_day).to_a
        else
          # Handle week wraparound (e.g., "Sat-Mon")
          return [ *start_day..6, *0..end_day ]
        end
      end
    end

    # Single day
    day_num = day_mapping[normalized]
    day_num ? [ day_num ] : []
  end

  def parse_time_range(time_text)
    normalized = time_text.downcase.strip

    # Check if closed
    if normalized.include?("closed") || normalized.include?("close")
      return { is_closed: true }
    end

    # Try to extract time range (e.g., "09:00 - 22:00", "9AM-10PM")
    time_pattern = /(\d{1,2}):?(\d{0,2})\s*(am|pm)?\s*[-–]\s*(\d{1,2}):?(\d{0,2})\s*(am|pm)?/i
    match = normalized.match(time_pattern)

    if match
      start_hour = match[1].to_i
      start_min = match[2].present? ? match[2].to_i : 0
      start_ampm = match[3]
      end_hour = match[4].to_i
      end_min = match[5].present? ? match[5].to_i : 0
      end_ampm = match[6]

      # Convert to 24-hour format
      start_hour = convert_to_24_hour(start_hour, start_ampm)
      end_hour = convert_to_24_hour(end_hour, end_ampm)

      if start_hour && end_hour
        return {
          opens_at: format_time(start_hour, start_min),
          closes_at: format_time(end_hour, end_min),
          is_closed: false
        }
      end
    end

    {}
  end

  def convert_to_24_hour(hour, ampm)
    return hour if ampm.nil? # Already 24-hour format

    case ampm.downcase
    when "am"
      hour == 12 ? 0 : hour
    when "pm"
      hour == 12 ? 12 : hour + 12
    else
      hour
    end
  end

  def format_time(hour, minute)
    sprintf("%02d:%02d", hour, minute)
  end

  def extract_image_url(doc)
    # Simple approach - find any img with GoJek characteristics
    images = doc.css('img')
    
    images.each do |img|
      src = img['src'] || img['data-src'] || img['data-lazy-src']
      next unless src.present?
      
      # Check if it's a GoJek image URL
      if src.include?('gojekapi.com') || src.include?('gofood')
        # Convert relative URLs to absolute
        src = src.start_with?('http') ? src : "https:#{src}"
        return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
      end
      
      # Check for other indicators it's a restaurant image
      alt_text = img['alt'].to_s.downcase
      if (img['data-nimg'] == '1' || img['fetchpriority'] == 'high') && 
         (alt_text.include?('restaurant') || alt_text.include?('eggs') || alt_text.length > 10)
        src = src.start_with?('http') ? src : "https:#{src}"
        return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
      end
    end

    nil
  end
end
