require "selenium-webdriver"
require "timeout"

class GrabParserService
  TIMEOUT_SECONDS = 20

  def parse(url)
    Rails.logger.info "=== Grab Selenium Parser Starting for URL: #{url} ==="
    return nil if url.blank?

    driver = nil
    begin
      Timeout.timeout(TIMEOUT_SECONDS) do
        # Setup Chrome with headless options
        driver = setup_chrome_driver
        
        Rails.logger.info "Grab: Navigating to URL with Selenium..."
        driver.get(url)
        
        # Wait for page to load
        Rails.logger.info "Grab: Waiting for page to load..."
        sleep(2)
        
        # Wait for content to appear
        wait = Selenium::WebDriver::Wait.new(timeout: 8)
        wait.until { driver.execute_script("return document.readyState") == "complete" }
        
        current_url = driver.current_url
        Rails.logger.info "Grab: Final URL: #{current_url}"
        
        # Extract data from the page
        data = {
          name: extract_restaurant_name_selenium(driver),
          address: extract_address_selenium(driver),
          cuisines: extract_cuisines_selenium(driver),
          working_hours: extract_working_hours_selenium(driver),
          rating: extract_rating_selenium(driver),
          image_url: extract_image_url_selenium(driver)
        }
        
        Rails.logger.info "Grab: Extracted data: #{data.inspect}"
        data
      end
    rescue Timeout::Error
      Rails.logger.error "Timeout while parsing Grab URL: #{url}"
      nil
    rescue => e
      Rails.logger.error "Error parsing Grab URL #{url}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    ensure
      driver&.quit
      Rails.logger.info "Grab: Browser closed"
    end
  end

  private

  def setup_chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new
    
    # Headless mode for server deployment
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--window-size=1920,1080')
    
    # User agent to avoid detection
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
    
    Rails.logger.info "Grab: Starting Chrome driver in headless mode"
    Selenium::WebDriver.for(:chrome, options: options)
  end

  def extract_restaurant_name_selenium(driver)
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
      begin
        element = driver.find_element(:css, selector)
        if element&.text&.present?
          name = element.text.strip
          return name if name.length > 2
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Fallback: try to extract from title
    begin
      title = driver.title
      if title.present?
        # Grab titles often have format "Restaurant Name ⭐ 4.7"
        name = title.split("⭐").first&.strip
        return name if name.present? && name.length > 3
      end
    rescue
      # Ignore
    end

    nil
  end

  def extract_address_selenium(driver)
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
      begin
        element = driver.find_element(:css, selector)
        if element&.text&.present?
          address = element.text.strip
          return address if address.length > 10 # Reasonable address length
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    nil
  end

  def extract_cuisines_selenium(driver)
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
      begin
        elements = driver.find_elements(:css, selector)
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
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Clean and deduplicate cuisines
    cuisines.map(&:strip).uniq.reject(&:blank?).first(3)
  end

  def extract_rating_selenium(driver)
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
      begin
        element = driver.find_element(:css, selector)
        if element&.text&.present?
          # Extract number from text (e.g., "4.5" from "4.5⭐" or "Rating: 4.5")
          rating_text = element.text.strip
          rating_match = rating_text.match(/(\d+\.?\d*)/)
          if rating_match
            rating = rating_match[1].to_f
            return rating if rating >= 1.0 && rating <= 5.0
          end
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Try to extract from title as fallback
    begin
      title = driver.title
      if title.present?
        # Grab titles often have format "Restaurant Name ⭐ 4.7"
        title_match = title.match(/⭐\s*(\d+\.?\d*)/)
        if title_match
          rating = title_match[1].to_f
          return rating if rating >= 1.0 && rating <= 5.0
        end
      end
    rescue
      # Ignore
    end

    nil
  end

  def extract_working_hours_selenium(driver)
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
      begin
        elements = driver.find_elements(:css, selector)
        if elements.any?
          working_hours = parse_working_hours_from_selenium_elements(elements)
          break if working_hours.any?
        end
      rescue
        # Continue to next selector
      end
    end

    working_hours
  end

  def parse_working_hours_from_selenium_elements(elements)
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

  def extract_image_url_selenium(driver)
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
      begin
        element = driver.find_element(:css, selector)
        if element
          src = element.attribute('src') || element.attribute('data-src') || element.attribute('data-lazy-src')
          if src.present?
            # Convert relative URLs to absolute
            src = src.start_with?('http') ? src : "https:#{src}"
            return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
          end
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Try to find any image in the header/hero section
    hero_sections = ['.hero', '.header', '.merchant-header', '[class*="header"]']
    hero_sections.each do |section_selector|
      begin
        section = driver.find_element(:css, section_selector)
        if section
          img = section.find_element(:css, 'img')
          if img
            src = img.attribute('src') || img.attribute('data-src') || img.attribute('data-lazy-src')
            if src.present?
              src = src.start_with?('http') ? src : "https:#{src}"
              return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
            end
          end
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next section
      end
    end

    nil
  end
end
