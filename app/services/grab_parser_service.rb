require "nokogiri"
require "open-uri"
require "timeout"

class GrabParserService
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
      Rails.logger.error "Timeout while parsing Grab URL: #{url}"
      nil
    rescue => e
      Rails.logger.error "Error parsing Grab URL #{url}: #{e.message}"
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
      "DNT" => "1",
      "Connection" => "keep-alive",
      "Upgrade-Insecure-Requests" => "1"
    }

    begin
      Rails.logger.info "Fetching Grab page: #{url}"
      content = URI.open(url, headers).read
      Rails.logger.info "Successfully fetched Grab page, size: #{content.length} bytes"
      content
    rescue => e
      Rails.logger.error "Failed to fetch Grab page #{url}: #{e.class} - #{e.message}"
      nil
    end
  end

  def extract_restaurant_name(doc)
    # Try multiple selectors for restaurant name
    selectors = [
      'h1.name___1Ls94',  # Current Grab structure
      'h1[data-testid="merchant-name"]',
      "h1.merchant-name",
      "h1",
      ".merchant-name",
      ".restaurant-name",
      '[data-testid="merchant-name"]',
      ".MerchantHeader__name",
      ".name"
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.present?
        name = element.text.strip
        return name if name.length > 2
      end
    end

    # Fallback: try to extract from title
    title = doc.css("title").first
    if title && title.text.present?
      # Grab titles often have format "Restaurant Name ⭐ 4.7"
      name = title.text.split("⭐").first&.strip
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
      ".MerchantHeader__address",
      '[class*="address"]',
      ".location"
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

    # Try multiple selectors for cuisine types, including the specific Grab selector
    selectors = [
      'h3.cuisine___3sorn.infoRow___3TzCZ',  # Current Grab specific selector
      'h3.cuisine___3sorn',  # Alternative without infoRow class
      '[data-testid="merchant-cuisine"]',
      ".cuisine-type",
      ".category",
      ".MerchantHeader__cuisine",
      '[class*="cuisine"]',
      '[class*="category"]',
      ".tags"
    ]

    selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip
        if text.present? && text.length < 50 # Reasonable cuisine name length
          # Split by common separators
          text.split(/[,•·|&]/).each do |cuisine|
            cleaned = cuisine.strip
            cuisines << cleaned if cleaned.present?
          end
        end
      end

      break if cuisines.any?
    end

    # Clean and deduplicate cuisines
    cuisines.map(&:strip).uniq.reject(&:blank?).first(3)
  end

  def extract_rating(doc)
    # Try multiple selectors for rating
    selectors = [
      '.ratingText___1Q08c',  # Current Grab structure
      '[data-testid="merchant-rating"]',
      ".rating",
      ".star-rating",
      ".MerchantHeader__rating",
      '[class*="rating"]'
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.present?
        # Extract number from text (e.g., "4.5" from "4.5⭐" or "Rating: 4.5")
        rating_text = element.text.strip
        rating_match = rating_text.match(/(\d+\.?\d*)/)
        if rating_match
          rating = rating_match[1].to_f
          return rating if rating >= 1.0 && rating <= 5.0
        end
      end
    end

    # Try to extract from title as fallback
    title = doc.css("title").first
    if title && title.text.present?
      # Grab titles often have format "Restaurant Name ⭐ 4.7"
      title_match = title.text.match(/⭐\s*(\d+\.?\d*)/)
      if title_match
        rating = title_match[1].to_f
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
      ".MerchantHeader__hours",
      '[class*="hours"]',
      ".schedule"
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
    # Try multiple selectors for restaurant image
    selectors = [
      '[data-testid="merchant-image"] img',
      '.merchant-image img',
      '.restaurant-image img',
      '.MerchantHeader__image img',
      '[class*="image"] img',
      '.cover-image img',
      '.hero-image img',
      'img[alt*="restaurant"]',
      'img[alt*="merchant"]'
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element
        src = element['src'] || element['data-src'] || element['data-lazy-src']
        if src.present?
          # Convert relative URLs to absolute
          src = src.start_with?('http') ? src : "https:#{src}"
          return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
        end
      end
    end

    # Try to find any image in the header/hero section
    hero_sections = ['.hero', '.header', '.merchant-header', '[class*="header"]']
    hero_sections.each do |section_selector|
      section = doc.css(section_selector).first
      if section
        img = section.css('img').first
        if img
          src = img['src'] || img['data-src'] || img['data-lazy-src']
          if src.present?
            src = src.start_with?('http') ? src : "https:#{src}"
            return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
          end
        end
      end
    end

    nil
  end
end
