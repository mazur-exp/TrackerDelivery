require "selenium-webdriver"
require "timeout"

class GojekParserService
  TIMEOUT_SECONDS = 30

  def parse(url)
    Rails.logger.info "=== GoJek Selenium Parser Starting for URL: #{url} ==="
    return nil if url.blank?

    driver = nil
    begin
      Timeout.timeout(TIMEOUT_SECONDS) do
        # Setup Chrome with headless options
        driver = setup_chrome_driver
        
        Rails.logger.info "GoJek: Navigating to URL with Selenium..."
        driver.get(url)
        
        # Wait for page to load and JavaScript to execute
        Rails.logger.info "GoJek: Waiting for page to load..."
        sleep(3)
        
        # Wait for content to appear or redirects to complete
        wait = Selenium::WebDriver::Wait.new(timeout: 10)
        wait.until { driver.execute_script("return document.readyState") == "complete" }
        
        # Check if we were redirected to a full GoJek page
        current_url = driver.current_url
        Rails.logger.info "GoJek: Final URL after redirects: #{current_url}"
        
        # Extract data from the page
        data = {
          name: extract_restaurant_name_selenium(driver),
          address: extract_address_selenium(driver),
          cuisines: extract_cuisines_selenium(driver),
          working_hours: extract_working_hours_selenium(driver),
          rating: extract_rating_selenium(driver),
          image_url: extract_image_url_selenium(driver)
        }
        
        Rails.logger.info "GoJek: Extracted data: #{data.inspect}"
        data
      end
    rescue Timeout::Error
      Rails.logger.error "Timeout while parsing GoJek URL: #{url}"
      nil
    rescue => e
      Rails.logger.error "Error parsing GoJek URL #{url}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    ensure
      driver&.quit
      Rails.logger.info "GoJek: Browser closed"
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
    
    Rails.logger.info "GoJek: Starting Chrome driver in headless mode"
    Selenium::WebDriver.for(:chrome, options: options)
  end
  
  def extract_restaurant_name_selenium(driver)
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
      begin
        element = driver.find_element(:css, selector)
        if element&.text&.present?
          return element.text.strip
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    # Fallback: try to extract from title
    begin
      title = driver.title
      if title.present?
        # GoFood titles often have format "Restaurant Name | GoFood"
        name = title.split("|").first&.strip
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
      '[class*="address"]'
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

    # Look for font elements with dir="auto" that contain comma-separated text
    begin
      fonts = driver.find_elements(:css, 'font[dir="auto"]')
      fonts.each do |font|
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
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Try broader search
    end
    
    # If no cuisines found, try broader search
    if cuisines.empty?
      begin
        elements = driver.find_elements(:css, 'p, div, span')
        elements.each do |element|
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
      rescue
        # Ignore
      end
    end

    # Clean and deduplicate cuisines
    cuisines.map(&:strip).uniq.reject(&:blank?).first(3)
  end
  
  def extract_rating_selenium(driver)
    Rails.logger.info "=== GoJek Selenium Rating Debug - Starting ==="
    
    # Look for any p element with numeric content and containing "gf" or "label" in class
    begin
      p_elements = driver.find_elements(:css, 'p')
      Rails.logger.info "Found #{p_elements.length} p elements"
      
      p_elements.each_with_index do |p, i|
        text = p.text.strip
        classes = p.attribute('class').to_s
        
        if text.match?(/^\d+(\.\d+)?$/) && classes.match?(/gf|label/i)
          rating = text.to_f
          Rails.logger.info "Found potential rating P#{i}: text='#{text}' classes='#{classes}' rating=#{rating}"
          
          if rating >= 1.0 && rating <= 5.0
            # Check if parent has SVG
            parent = p.find_element(:xpath, '..')
            has_svg = !parent.find_elements(:css, 'svg').empty?
            Rails.logger.info "  -> Parent has SVG: #{has_svg}"
            
            if has_svg
              Rails.logger.info "  -> RETURNING RATING: #{rating}"
              return rating
            end
          end
        end
      end
    rescue => e
      Rails.logger.info "Error searching p elements: #{e.message}"
    end
    
    # Even broader search - look for any numeric content near SVG
    Rails.logger.info "=== Broader search: Any numeric element near star SVG ==="
    begin
      svgs = driver.find_elements(:css, 'svg[viewBox="0 0 24 24"]')
      Rails.logger.info "Found #{svgs.length} SVG elements"
      
      svgs.each_with_index do |svg, i|
        Rails.logger.info "Checking SVG#{i}"
        
        # Look in parent container for any numeric element
        begin
          container = svg.find_element(:xpath, '../..')
          elements = container.find_elements(:css, '*')
          
          elements.each do |element|
            text = element.text.strip
            if text.match?(/^\d+(\.\d+)?$/)
              rating = text.to_f
              if rating >= 1.0 && rating <= 5.0
                Rails.logger.info "Found rating #{rating} near SVG in element: #{element.tag_name}"
                return rating
              end
            end
          end
        rescue
          # Continue to next SVG
        end
      end
    rescue => e
      Rails.logger.info "Error in broader search: #{e.message}"
    end
    
    Rails.logger.info "=== No rating found ==="
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
      '[class*="hours"]'
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
  
  def extract_image_url_selenium(driver)
    # Simple approach - find any img with GoJek characteristics
    begin
      images = driver.find_elements(:css, 'img')
      
      images.each do |img|
        src = img.attribute('src') || img.attribute('data-src') || img.attribute('data-lazy-src')
        next unless src.present?
        
        # Check if it's a GoJek image URL
        if src.include?('gojekapi.com') || src.include?('gofood')
          # Convert relative URLs to absolute
          src = src.start_with?('http') ? src : "https:#{src}"
          return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
        end
        
        # Check for other indicators it's a restaurant image
        alt_text = img.attribute('alt').to_s.downcase
        if (img.attribute('data-nimg') == '1' || img.attribute('fetchpriority') == 'high') && 
           (alt_text.include?('restaurant') || alt_text.include?('eggs') || alt_text.length > 10)
          src = src.start_with?('http') ? src : "https:#{src}"
          return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
        end
      end
    rescue => e
      Rails.logger.info "Error extracting image: #{e.message}"
    end

    nil
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
