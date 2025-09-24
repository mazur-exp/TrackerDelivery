require "selenium-webdriver"
require "timeout"
require "json"
require "cgi"
require_relative "retryable_parser"

class GrabParserService < RetryableParser
  TIMEOUT_SECONDS = 20

  def parse(url)
    parse_with_retry(url)
  end

  def check_status_only(url)
    Rails.logger.info "=== Grab Status Check Only for URL: #{url} ==="
    return { is_open: nil, status_text: "error", error: "URL is blank" } if url.blank?

    driver = nil
    begin
      Timeout.timeout(15) do  # Shorter timeout for status check
        driver = setup_chrome_driver

        Rails.logger.info "Grab Status: Navigating to URL..."
        driver.get(url)

        # Wait briefly for page to load
        sleep(2)
        wait = Selenium::WebDriver::Wait.new(timeout: 5)
        wait.until { driver.execute_script("return document.readyState") == "complete" }

        # Try to extract only status information quickly
        json_data = extract_json_data_selenium(driver)
        if json_data && json_data[:status]
          Rails.logger.info "Grab Status: Found status in JSON data"
          return json_data[:status]
        end

        # Fallback: look for DOM indicators
        status = extract_status_from_dom(driver)
        Rails.logger.info "Grab Status: Status check completed - #{status[:status_text]}"
        return status
      end

    rescue Timeout::Error => e
      Rails.logger.error "Grab Status: Timeout during status check: #{e.message}"
      return { is_open: nil, status_text: "timeout", error: "Request timed out" }
    rescue => e
      Rails.logger.error "Grab Status: Error during status check: #{e.message}"
      return { is_open: nil, status_text: "error", error: e.message }
    ensure
      if driver
        driver.quit rescue nil
        Rails.logger.info "Grab Status: Browser closed"
      end
    end
  end

  private

  def parse_implementation(url)
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

        # First try to extract from JSON data (more reliable)
        json_data = extract_json_data_selenium(driver)
        if json_data && json_data.any?
          Rails.logger.info "Grab: Using JSON data extraction"
          data = json_data

          # If address is missing, try to get it from DOM
          if data[:address].blank?
            Rails.logger.info "Grab: Address missing in JSON, trying DOM extraction"
            dom_address = extract_address_selenium(driver)
            data[:address] = dom_address if dom_address.present?
          end
        else
          Rails.logger.info "Grab: Falling back to DOM extraction"
          # Extract data from the page DOM (fallback)
          data = {
            name: extract_restaurant_name_selenium(driver),
            address: extract_address_selenium(driver),
            cuisines: extract_cuisines_selenium(driver),
            working_hours: extract_working_hours_selenium(driver),
            rating: extract_rating_selenium(driver),
            image_url: extract_image_url_selenium(driver)
          }
        end

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

  def extract_json_data_selenium(driver)
    begin
      # Find script tags that contain restaurant data
      scripts = driver.find_elements(:css, "script")

      scripts.each do |script|
        content = script.attribute("innerHTML")
        next unless content && content.include?('"props"') && content.include?("ssrRestaurantData")

        # Extract JSON data
        json_start = content.index('{"props"')
        next unless json_start

        json_content = content[json_start..-1]

        # Find the end of JSON object
        brace_count = 0
        json_end = nil
        json_content.each_char.with_index do |char, i|
          if char == "{"
            brace_count += 1
          elsif char == "}"
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

        # Extract restaurant data from parsed JSON
        restaurant_data = parsed.dig("props", "pageProps", "ssrRestaurantData")
        next unless restaurant_data

        Rails.logger.info "Grab: Found restaurant data in JSON: #{restaurant_data.keys}"

        return extract_restaurant_info_from_json(restaurant_data)
      end

      nil
    rescue => e
      Rails.logger.error "Grab: Error extracting JSON data: #{e.message}"
      nil
    end
  end

  def extract_restaurant_info_from_json(restaurant_data)
    # Extract restaurant information from JSON data
    cuisines = []
    if restaurant_data["cuisine"].present?
      cuisines = [ restaurant_data["cuisine"] ]
    end

    # Extract working hours
    working_hours = extract_working_hours_from_json(restaurant_data["openingHours"])

    # Extract rating if available
    rating = restaurant_data["averageRating"] || restaurant_data["rating"]

    # Extract status from opening hours
    status = extract_status_from_json(restaurant_data["openingHours"])

    # Extract coordinates
    coordinates = extract_coordinates_from_json(restaurant_data)

    # Extract address from restaurant data - use coordinates if no address
    address = extract_address_from_json(restaurant_data)

    # If no address in JSON but we have coordinates, use coordinates as address
    if address.blank? && coordinates
      Rails.logger.info "Grab: No address in JSON, using coordinates as address: #{coordinates.inspect}"
      address = "#{coordinates[:latitude]}, #{coordinates[:longitude]}"
    end

    {
      name: restaurant_data["name"],
      address: address,
      coordinates: coordinates,
      cuisines: cuisines,
      working_hours: working_hours,
      rating: rating,
      image_url: restaurant_data["photoHref"],
      status: status
    }
  end

  def extract_coordinates_from_json(restaurant_data)
    # Extract coordinates from latlng field
    if restaurant_data["latlng"].is_a?(Hash)
      lat = restaurant_data["latlng"]["latitude"]
      lng = restaurant_data["latlng"]["longitude"]

      if lat && lng
        Rails.logger.info "Grab: Found coordinates: #{lat}, #{lng}"
        return {
          latitude: lat.to_f,
          longitude: lng.to_f
        }
      end
    end

    nil
  end

  def extract_address_from_json(restaurant_data)
    # Try to extract address from JSON first
    address = nil
    if restaurant_data["address"]
      addr_data = restaurant_data["address"]
      if addr_data.is_a?(Hash)
        # Try to build address from parts
        address_parts = []
        address_parts << addr_data["house"] if addr_data["house"].present?
        address_parts << addr_data["street"] if addr_data["street"].present?
        address_parts << addr_data["suburb"] if addr_data["suburb"].present?
        address_parts << addr_data["city"] if addr_data["city"].present?
        address_parts << addr_data["combinedAddress"] if addr_data["combinedAddress"].present?

        address = address_parts.join(", ") if address_parts.any?
        address = addr_data["combinedAddress"] if address.blank? && addr_data["combinedAddress"].present?
      elsif addr_data.is_a?(String)
        address = addr_data
      end
    end

    address
  end

  def extract_status_from_json(opening_hours_data)
    return { is_open: true, status_text: "open" } unless opening_hours_data.is_a?(Hash)

    # Check if restaurant is currently open
    is_currently_open = opening_hours_data["open"]
    displayed_hours = opening_hours_data["displayedHours"]
    temp_closed = opening_hours_data["tempClosed"]

    # Determine status
    if temp_closed == true
      { is_open: false, status_text: "temporarily_closed", opening_info: displayed_hours }
    elsif is_currently_open == false
      { is_open: false, status_text: "closed", opening_info: displayed_hours }
    elsif is_currently_open == true
      { is_open: true, status_text: "open", opening_info: displayed_hours }
    else
      # Fallback - check displayed hours text
      if displayed_hours && displayed_hours.downcase.include?("closed")
        { is_open: false, status_text: "closed", opening_info: displayed_hours }
      else
        { is_open: true, status_text: "open", opening_info: displayed_hours }
      end
    end
  end

  def extract_status_from_dom(driver)
    # Quick DOM-based status extraction for monitoring
    begin
      # Look for common status indicators in the DOM
      status_elements = [
        'span[data-testid="restaurant-status"]',
        '.restaurant-status',
        '[class*="status"]',
        '[class*="opening"]'
      ]

      status_elements.each do |selector|
        begin
          elements = driver.find_elements(:css, selector)
          elements.each do |element|
            text = element.text.strip.downcase
            next if text.blank?

            # Check for closed indicators
            if text.include?("closed") || text.include?("temporary") || text.include?("unavailable")
              return { is_open: false, status_text: "closed", opening_info: text }
            elsif text.include?("open") || text.include?("available")
              return { is_open: true, status_text: "open", opening_info: text }
            end
          end
        rescue => e
          Rails.logger.debug "Grab Status DOM: Error with selector #{selector}: #{e.message}"
          next
        end
      end

      # Default assumption if no clear indicators found
      { is_open: true, status_text: "open", opening_info: "status_unknown" }
    rescue => e
      Rails.logger.error "Grab Status DOM: Error extracting status: #{e.message}"
      { is_open: nil, status_text: "error", error: e.message }
    end
  end

  def extract_working_hours_from_json(opening_hours_data)
    return [] unless opening_hours_data.is_a?(Hash)

    hours = []
    day_mapping = {
      "mon" => 0, "tue" => 1, "wed" => 2, "thu" => 3,
      "fri" => 4, "sat" => 5, "sun" => 6
    }

    day_mapping.each do |day_key, day_num|
      day_hours = opening_hours_data[day_key]
      next unless day_hours

      # Parse time format like "12:00am-11:59pm"
      if day_hours.include?("-")
        times = day_hours.split("-")
        opens_at = parse_grab_time(times[0])
        closes_at = parse_grab_time(times[1])

        if opens_at && closes_at
          hours << {
            day_of_week: day_num,
            opens_at: opens_at,
            closes_at: closes_at,
            is_closed: false
          }
        end
      end
    end

    hours
  end

  def parse_grab_time(time_str)
    # Parse time format like "12:00am", "11:59pm"
    return nil unless time_str

    time_str = time_str.strip.downcase

    # Extract hour, minute, and am/pm
    if match = time_str.match(/(\d{1,2}):(\d{2})(am|pm)/)
      hour = match[1].to_i
      minute = match[2].to_i
      ampm = match[3]

      # Convert to 24-hour format
      if ampm == "am"
        hour = 0 if hour == 12
      else # pm
        hour += 12 unless hour == 12
      end

      sprintf("%02d:%02d", hour, minute)
    end
  end

  def cleanup_driver_resources
    # Force cleanup any existing drivers
    begin
      @current_driver&.quit
    rescue => e
      Rails.logger.warn "Grab: Error during driver cleanup: #{e.message}"
    ensure
      @current_driver = nil
    end
    
    # Kill any remaining Chrome processes (macOS/Linux)
    begin
      if RUBY_PLATFORM.include?("darwin") || RUBY_PLATFORM.include?("linux")
        system("pkill -f 'chrome.*--headless' > /dev/null 2>&1")
      end
    rescue => e
      Rails.logger.warn "Grab: Error killing Chrome processes: #{e.message}"
    end
  end

  def setup_chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new

    # Essential headless mode flags for production servers
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-software-rasterizer")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-plugins")
    options.add_argument("--disable-images")
    options.add_argument("--disable-web-security")
    options.add_argument("--disable-features=TranslateUI")
    options.add_argument("--disable-ipc-flooding-protection")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--remote-debugging-port=9222")

    # Additional flags for Chromium compatibility
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--disable-features=VizDisplayCompositor")

    # Memory optimization for containers
    options.add_argument("--memory-pressure-off")
    options.add_argument("--max_old_space_size=4096")

    # Detect Chrome binary with improved logic
    chrome_binary = detect_chrome_binary

    # Set architecture-appropriate user agent
    arch = detect_architecture
    if arch == "arm64" || chrome_binary&.include?("chromium")
      options.add_argument("--user-agent=Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    else
      options.add_argument("--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    end

    if File.exist?(chrome_binary)
      options.binary = chrome_binary
      Rails.logger.info "Grab: Using Chrome binary: #{chrome_binary}"
    else
      Rails.logger.error "Grab: Chrome binary not found at: #{chrome_binary}"
      raise "Chrome binary not accessible at #{chrome_binary}"
    end

    # Detect and validate ChromeDriver
    chromedriver_path = detect_chromedriver_path
    Rails.logger.info "Grab: Using ChromeDriver: #{chromedriver_path}"

    Rails.logger.info "Grab: Starting Chrome driver in headless mode with production optimizations"

    # Always use explicit service with detected ChromeDriver path
    begin
      service = Selenium::WebDriver::Service.chrome(path: chromedriver_path)
      Rails.logger.info "Grab: Created ChromeDriver service with path: #{chromedriver_path}"
      driver = Selenium::WebDriver.for(:chrome, service: service, options: options)
      Rails.logger.info "Grab: Successfully created WebDriver instance"
      @current_driver = driver
      driver
    rescue => e
      Rails.logger.error "Grab: Failed to create WebDriver: #{e.class} - #{e.message}"
      Rails.logger.error "Grab: Chrome binary: #{chrome_binary} (exists: #{File.exist?(chrome_binary)})"
      Rails.logger.error "Grab: ChromeDriver: #{chromedriver_path} (exists: #{File.exist?(chromedriver_path)})"
      raise e
    end
  end

  private

  def detect_chrome_binary
    # Priority order for Chrome binary detection
    candidates = [
      ENV["CHROME_BIN"],
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", # Mac
      "/Applications/Chromium.app/Contents/MacOS/Chromium", # Mac Chromium
      "/usr/bin/google-chrome-stable", # Linux
      "/usr/bin/google-chrome", # Linux
      "/usr/bin/chromium", # Linux
      "/usr/bin/chromium-browser" # Linux
    ].compact

    candidates.each do |path|
      if File.exist?(path) && File.executable?(path)
        Rails.logger.info "Grab: Found Chrome binary at: #{path}"
        return path
      end
    end

    # Last resort: search the filesystem
    Rails.logger.warn "Grab: No Chrome binary found in standard locations, searching filesystem..."
    search_result = `find /usr -name "chrome*" -o -name "chromium*" -type f 2>/dev/null | grep -E "(chrome|chromium)$" | head -1`.strip

    if search_result.present? && File.exist?(search_result)
      Rails.logger.info "Grab: Found Chrome binary via search: #{search_result}"
      return search_result
    end

    Rails.logger.error "Grab: No Chrome binary found anywhere"
    raise "No Chrome/Chromium binary found on system"
  end

  def detect_chromedriver_path
    # Priority order for ChromeDriver detection
    candidates = [
      ENV["CHROMEDRIVER_PATH"],
      "/usr/local/bin/chromedriver",
      "/usr/bin/chromedriver",
      "/usr/lib/chromium/chromedriver",
      "/usr/lib/chromium-browser/chromedriver"
    ].compact

    candidates.each do |path|
      if File.exist?(path) && File.executable?(path)
        Rails.logger.info "Grab: Found ChromeDriver at: #{path}"
        return path
      end
    end

    # Last resort: search the filesystem
    Rails.logger.warn "Grab: No ChromeDriver found in standard locations, searching filesystem..."
    search_result = `find /usr -name "chromedriver" -type f 2>/dev/null | head -1`.strip

    if search_result.present? && File.exist?(search_result)
      Rails.logger.info "Grab: Found ChromeDriver via search: #{search_result}"
      return search_result
    end

    Rails.logger.error "Grab: No ChromeDriver found anywhere"
    raise "ChromeDriver not found on system"
  end

  def detect_architecture
    arch = `uname -m`.strip rescue "unknown"
    case arch
    when "aarch64", "arm64"
      "arm64"
    when "x86_64", "amd64"
      "amd64"
    else
      arch
    end
  end

  def extract_restaurant_name_selenium(driver)
    # Try multiple selectors for restaurant name
    selectors = [
      "h1.name___1Ls94",  # Current Grab structure
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
      "h3.cuisine___3sorn.infoRow___3TzCZ",  # Current Grab specific selector
      "h3.cuisine___3sorn",  # Alternative without infoRow class
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
      ".ratingText___1Q08c",  # Current Grab structure
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
      ".merchant-image img",
      ".restaurant-image img",
      ".MerchantHeader__image img",
      '[class*="image"] img',
      ".cover-image img",
      ".hero-image img",
      'img[alt*="restaurant"]',
      'img[alt*="merchant"]'
    ]

    selectors.each do |selector|
      begin
        element = driver.find_element(:css, selector)
        if element
          src = element.attribute("src") || element.attribute("data-src") || element.attribute("data-lazy-src")
          if src.present?
            # Convert relative URLs to absolute
            src = src.start_with?("http") ? src : "https:#{src}"
            return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
          end
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Try to find any image in the header/hero section
    hero_sections = [ ".hero", ".header", ".merchant-header", '[class*="header"]' ]
    hero_sections.each do |section_selector|
      begin
        section = driver.find_element(:css, section_selector)
        if section
          img = section.find_element(:css, "img")
          if img
            src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
            if src.present?
              src = src.start_with?("http") ? src : "https:#{src}"
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
