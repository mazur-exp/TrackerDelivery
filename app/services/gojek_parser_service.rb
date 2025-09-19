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
        
        # Try to click on restaurant info button to get detailed info
        click_restaurant_info_button(driver)
        
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
  
  def click_restaurant_info_button(driver)
    Rails.logger.info "=== Attempting to click restaurant info button ==="
    
    begin
      # Look for clickable elements that might open the info modal
      # Try SVG path elements with the arrow pattern
      arrow_elements = driver.find_elements(:css, 'svg path[d*="M8.297 6.71a1 1 0 0 1 1.406-1.42l5.954 5.89"]')
      
      if arrow_elements.any?
        Rails.logger.info "Found #{arrow_elements.length} arrow SVG elements"
        # Click the first arrow element's parent button/clickable area
        arrow_elements.first.find_element(:xpath, '../..').click
        Rails.logger.info "Clicked arrow element, waiting for modal to appear..."
        sleep(2) # Wait for modal to appear
        return true
      end
      
      # Alternative: look for any clickable element near restaurant name
      clickable_selectors = [
        'button[aria-expanded]',
        '[role="button"]',
        'div[class*="cursor-pointer"]',
        'div[class*="clickable"]'
      ]
      
      clickable_selectors.each do |selector|
        elements = driver.find_elements(:css, selector)
        Rails.logger.info "Found #{elements.length} elements with selector: #{selector}"
        
        if elements.any?
          elements.first.click
          Rails.logger.info "Clicked element with selector: #{selector}"
          sleep(2)
          return true
        end
      end
      
    rescue => e
      Rails.logger.info "Error clicking restaurant info button: #{e.message}"
    end
    
    Rails.logger.info "=== No clickable info button found ==="
    false
  end
  
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
    Rails.logger.info "=== Extracting Address ==="
    
    # First try to find address in modal window
    begin
      # Look for the specific address structure in modal
      modal_address_elements = driver.find_elements(:css, 'div.text-gf-content-muted.gf-body-s font[dir="auto"]')
      Rails.logger.info "Found #{modal_address_elements.length} modal address elements"
      
      modal_address_elements.each_with_index do |element, i|
        text = element.text.strip
        Rails.logger.info "Modal address element #{i}: '#{text}'"
        
        # Check if this looks like an address (contains location indicators)
        if text.length > 20 && 
           (text.downcase.include?('jl.') || text.downcase.include?('street') || 
            text.downcase.include?('canggu') || text.downcase.include?('bali') ||
            text.downcase.include?('kec.') || text.downcase.include?('regency'))
          Rails.logger.info "Found address in modal: #{text}"
          return text
        end
      end
    rescue => e
      Rails.logger.info "Error searching modal address: #{e.message}"
    end
    
    # Fallback to original selectors
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
          Rails.logger.info "Found address with selector #{selector}: #{address}"
          return address if address.length > 10 # Reasonable address length
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Continue to next selector
      end
    end

    Rails.logger.info "=== No address found ==="
    nil
  end
  
  def extract_cuisines_selenium(driver)
    cuisines = []

    # First get restaurant name to avoid confusion with cuisine categories
    restaurant_name = extract_restaurant_name_selenium(driver)
    Rails.logger.info "GoJek: Restaurant name: '#{restaurant_name}'"

    # First try the specific GoJek cuisine selector
    begin
      cuisine_elements = driver.find_elements(:css, 'p.text-gf-content-secondary.line-clamp-1')
      Rails.logger.info "GoJek: Found #{cuisine_elements.length} potential cuisine elements"
      
      # Also try alternative selectors
      alt_elements = driver.find_elements(:css, 'p[class*="text-gf-content-secondary"]')
      Rails.logger.info "GoJek: Found #{alt_elements.length} alternative elements"
      
      # Try looking for any p elements that might contain cuisines
      all_p_elements = driver.find_elements(:css, 'p')
      cuisine_candidates = all_p_elements.select { |p| 
        text = p.text.strip
        text.include?(',') && text.length > 5 && text.length < 100
      }
      Rails.logger.info "GoJek: Found #{cuisine_candidates.length} p elements with commas"
      
      cuisine_elements.each_with_index do |element, i|
        text = element.text.strip
        Rails.logger.info "GoJek: Cuisine element #{i}: '#{text}'"
        
        # Skip if this text matches the restaurant name
        if restaurant_name.present? && text.downcase == restaurant_name.downcase
          Rails.logger.info "GoJek: Skipping restaurant name: '#{text}'"
          next
        end
        
        # Check each element directly against our known cuisine categories
        text_normalized = text.downcase.strip
        Rails.logger.info "GoJek: Checking text against known categories: '#{text_normalized}'"
        
        # Our complete list of known Indonesian cuisine categories
        known_cuisine_categories = [
          "aneka nasi", "ayam & bebek", "bakmie", "bakso & soto", "barat", 
          "cepat saji", "chinese", "india", "indonesia", "jajanan", "jepang", 
          "kopi", "korea", "makanan sehat", "martabak", "minuman", "nasi goreng", 
          "pizza & pasta", "roti", "sate", "seafood", "steak", "sweets", 
          "thailand", "timur tengah"
        ]
        
        # Check if this text exactly matches one of our known categories
        if known_cuisine_categories.include?(text_normalized)
          Rails.logger.info "GoJek: Found exact match for cuisine category: '#{text_normalized}'"
          cuisines << text_normalized
        elsif text.include?(',') && text.length > 10 && text.length < 50
          # If it contains commas, check if it's a list of cuisine categories
          Rails.logger.info "GoJek: Checking comma-separated text for cuisine categories"
          
          # Skip obvious non-cuisine text
          next if text_normalized.include?('canggu') || text_normalized.include?('street') || 
                  text_normalized.include?('eat street') || text_normalized.include?('restaurant') ||
                  text_normalized.include?('promo') || text_normalized == restaurant_name&.downcase
          
          # Split by commas and check each part
          text.split(',').each do |part|
            part_normalized = part.strip.downcase
            if known_cuisine_categories.include?(part_normalized)
              Rails.logger.info "GoJek: Found cuisine in comma-separated list: '#{part_normalized}'"
              cuisines << part_normalized
            end
          end
        else
          Rails.logger.info "GoJek: Text does not match any known cuisine categories, skipping"
        end
      end
      
      # If no cuisines found with primary selector, try alternative approaches
      if cuisines.empty?
        Rails.logger.info "GoJek: No cuisines found with primary selector, trying alternatives"
        
        # Try alternative elements and all p elements with commas
        all_candidates = (alt_elements + cuisine_candidates).uniq
        
        all_candidates.each_with_index do |element, i|
          text = element.text.strip
          Rails.logger.info "GoJek: Alternative element #{i}: '#{text}'"
          
          # Skip if this text matches the restaurant name
          if restaurant_name.present? && text.downcase == restaurant_name.downcase
            Rails.logger.info "GoJek: Skipping restaurant name: '#{text}'"
            next
          end
          
          # Check if this looks like cuisine categories
          if text.include?(',') && text.length > 10 && text.length < 100
            # Skip location-based names
            next if text.downcase.include?('canggu') || text.downcase.include?('street') || 
                    text.downcase.include?('eat street') || text.downcase.include?('restaurant')
            
            # Check if any known cuisine categories are present
            known_cuisines = %w[aneka nasi bakmie ayam bebek bakso soto barat cepat saji chinese india indonesia jajanan jepang kopi korea makanan sehat martabak minuman nasi goreng pizza pasta roti sate seafood steak sweets thailand timur tengah]
            text_words = text.downcase.split(/[,\s&]+/).map(&:strip)
            has_known_cuisine = known_cuisines.any? { |cuisine| text_words.include?(cuisine) }
            
            if has_known_cuisine
              Rails.logger.info "GoJek: Alternative text contains known cuisine categories"
              text.split(',').each do |cuisine|
                cleaned = cuisine.strip.downcase
                if cleaned.present? && cleaned.length > 2 && cleaned.length < 30
                  cuisines << cleaned
                end
              end
              # Don't break here - continue checking other elements
              # break if cuisines.any?
            end
          end
        end
      end
      
    rescue Selenium::WebDriver::Error::NoSuchElementError => e
      Rails.logger.info "GoJek: Could not find specific cuisine selector: #{e.message}"
    end

    # Fallback: Look for font elements with dir="auto" that contain comma-separated text
    if cuisines.empty?
      begin
        fonts = driver.find_elements(:css, 'font[dir="auto"]')
        fonts.each do |font|
          text = font.text.strip
          
          # Check if it looks like cuisine text (contains commas, reasonable length)
          if text.include?(',') && text.length > 5 && text.length < 100
            # Skip if it looks like a restaurant name, food items, or contains unwanted text
            next if text.downcase.include?('only eggs') || 
                    text.downcase.include?('restaurant') ||
                    text.downcase.include?('super partner') ||
                    text.downcase.include?('soto') ||        # Skip food items like "Soto Daging Sapi"
                    text.downcase.include?('daging') ||      # Skip meat dishes
                    text.downcase.include?('sambal') ||      # Skip sauce/condiment names
                    text.downcase.include?('goreng') ||      # Skip fried dishes
                    text.downcase.include?('dan ') ||        # Skip Indonesian "and" - indicates food description
                    text.include?("\n") # Skip multiline text that might contain "Super Partner\nBarat"
            
            # Split by commas and clean up
            text.split(',').each do |cuisine|
              cleaned = cuisine.strip.downcase
              # Filter out non-cuisine terms
              next if cleaned.include?('super partner') ||
                      cleaned.include?('partner') ||
                      cleaned.length < 3 || # Too short
                      cleaned.length > 25   # Too long for a cuisine name
              
              if cleaned.present?
                cuisines << cleaned
              end
            end
            
            break if cuisines.any?
          end
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        # Try broader search
      end
    end
    
    # If no cuisines found, try broader search
    if cuisines.empty?
      begin
        elements = driver.find_elements(:css, 'p, div, span')
        elements.each do |element|
          text = element.text.strip
          
          # Look for text that might be cuisines
          if text.match?(/^[A-Za-z\s,&]+$/) && text.include?(',') && 
             text.length > 10 && text.length < 50 &&
             !text.downcase.include?('only eggs') &&
             !text.downcase.include?('restaurant') &&
             !text.downcase.include?('super partner') &&
             !text.downcase.include?('soto') &&
             !text.downcase.include?('daging') &&
             !text.downcase.include?('sambal') &&
             !text.downcase.include?('goreng') &&
             !text.downcase.include?('dan ') &&
             !text.include?("\n")
            
            text.split(',').each do |cuisine|
              cleaned = cuisine.strip
              # Filter out non-cuisine terms
              next if cleaned.downcase.include?('super partner') ||
                      cleaned.downcase.include?('partner') ||
                      cleaned.length < 3 ||
                      cleaned.length > 25
              
              cuisines << cleaned if cleaned.present?
            end
            
            break if cuisines.any?
          end
        end
      rescue
        # Ignore
      end
    end

    # Clean and deduplicate cuisines, then translate to English
    raw_cuisines = cuisines.map(&:strip).uniq.reject(&:blank?).first(3)
    CuisineTranslationService.translate_array(raw_cuisines)
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
    Rails.logger.info "=== Extracting Working Hours ==="
    working_hours = []

    # First try to extract from modal window
    begin
      # Look for "Opening hours" section
      opening_hours_headers = driver.find_elements(:css, 'h4.gf-label-m')
      Rails.logger.info "Found #{opening_hours_headers.length} h4 headers"
      
      opening_hours_headers.each_with_index do |header, i|
        header_text = header.text.strip.downcase
        Rails.logger.info "Header #{i}: '#{header_text}'"
        
        if header_text.include?('opening hours') || header_text.include?('hours')
          Rails.logger.info "Found opening hours header, looking for schedule data..."
          
          # Find the parent container with schedule data
          parent = header.find_element(:xpath, '..')
          schedule_rows = parent.find_elements(:css, 'div.flex.items-center.justify-between')
          Rails.logger.info "Found #{schedule_rows.length} schedule rows"
          
          schedule_rows.each_with_index do |row, j|
            begin
              day_element = row.find_element(:css, 'div.py-2.pr-9.gf-label-s')
              time_element = row.find_element(:css, 'div.text-left.gf-body-s')
              
              day_text = day_element.text.strip
              time_text = time_element.text.strip
              
              Rails.logger.info "Schedule row #{j}: #{day_text} -> #{time_text}"
              
              # Parse day and time
              day_hours = parse_modal_day_hours(day_text, time_text)
              working_hours.concat(day_hours) if day_hours.any?
              
            rescue => e
              Rails.logger.info "Error parsing schedule row #{j}: #{e.message}"
            end
          end
          
          break if working_hours.any?
        end
      end
    rescue => e
      Rails.logger.info "Error extracting modal working hours: #{e.message}"
    end

    # Fallback to original selectors
    if working_hours.empty?
      Rails.logger.info "No modal hours found, trying fallback selectors"
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
    end

    Rails.logger.info "=== Extracted #{working_hours.length} working hour entries ==="
    working_hours
  end
  
  def extract_image_url_selenium(driver)
    Rails.logger.info "=== GoJek Image Extraction Starting ==="
    
    begin
      # First try to find the specific restaurant avatar image with object-cover class
      restaurant_images = driver.find_elements(:css, 'img.object-cover')
      Rails.logger.info "Found #{restaurant_images.length} images with object-cover class"
      
      restaurant_images.each_with_index do |img, i|
        src = img.attribute('src') || img.attribute('data-src') || img.attribute('data-lazy-src')
        alt_text = img.attribute('alt').to_s
        width = img.attribute('width')
        height = img.attribute('height')
        fetchpriority = img.attribute('fetchpriority')
        data_nimg = img.attribute('data-nimg')
        
        Rails.logger.info "Image #{i}: src='#{src}' alt='#{alt_text}' width='#{width}' height='#{height}'"
        
        next unless src.present?
        
        # Check if it's the restaurant avatar (usually has dimensions like 98x98, high priority, etc.)
        if (width == '98' && height == '98') || 
           (fetchpriority == 'high') ||
           (data_nimg == '1' && alt_text.length > 10)
          
          # Check if it's a GoJek image URL
          if src.include?('gojekapi.com') || src.include?('gofood') || src.include?('darkroom')
            # Convert relative URLs to absolute
            src = src.start_with?('http') ? src : "https:#{src}"
            if src.match?(/\.(jpg|jpeg|png|webp)/i)
              Rails.logger.info "Found restaurant avatar: #{src}"
              return src
            end
          end
        end
      end
      
      # Fallback: find any img with GoJek characteristics
      all_images = driver.find_elements(:css, 'img')
      Rails.logger.info "Fallback: Found #{all_images.length} total images"
      
      all_images.each_with_index do |img, i|
        src = img.attribute('src') || img.attribute('data-src') || img.attribute('data-lazy-src')
        next unless src.present?
        
        Rails.logger.info "Fallback image #{i}: #{src}"
        
        # Check if it's a GoJek image URL
        if src.include?('gojekapi.com') || src.include?('gofood') || src.include?('darkroom')
          # Convert relative URLs to absolute
          src = src.start_with?('http') ? src : "https:#{src}"
          if src.match?(/\.(jpg|jpeg|png|webp)/i)
            Rails.logger.info "Found GoJek image: #{src}"
            return src
          end
        end
        
        # Check for other indicators it's a restaurant image
        alt_text = img.attribute('alt').to_s.downcase
        if (img.attribute('data-nimg') == '1' || img.attribute('fetchpriority') == 'high') && 
           (alt_text.include?('restaurant') || alt_text.include?('eggs') || alt_text.length > 10)
          src = src.start_with?('http') ? src : "https:#{src}"
          if src.match?(/\.(jpg|jpeg|png|webp)/i)
            Rails.logger.info "Found restaurant image by characteristics: #{src}"
            return src
          end
        end
      end
    rescue => e
      Rails.logger.error "Error extracting image: #{e.message}"
    end

    Rails.logger.info "=== No image found ==="
    nil
  end
  
  def parse_modal_day_hours(day_text, time_text)
    # Map day names to day numbers
    day_mapping = {
      "monday" => 0, "mon" => 0,
      "tuesday" => 1, "tue" => 1, "tues" => 1,
      "wednesday" => 2, "wed" => 2,
      "thursday" => 3, "thu" => 3, "thurs" => 3,
      "friday" => 4, "fri" => 4,
      "saturday" => 5, "sat" => 5,
      "sunday" => 6, "sun" => 6
    }

    day_num = day_mapping[day_text.downcase.strip]
    return [] unless day_num

    # Parse time (format like "07:00-23:00")
    if time_text.downcase.include?('closed') || time_text.downcase.include?('close')
      return [{
        day_of_week: day_num,
        opens_at: nil,
        closes_at: nil,
        is_closed: true
      }]
    end

    # Parse time range like "07:00-23:00"
    time_parts = time_text.split('-').map(&:strip)
    if time_parts.length == 2
      opens_at = time_parts[0]
      closes_at = time_parts[1]
      
      # Validate time format
      if opens_at.match?(/^\d{2}:\d{2}$/) && closes_at.match?(/^\d{2}:\d{2}$/)
        return [{
          day_of_week: day_num,
          opens_at: opens_at,
          closes_at: closes_at,
          is_closed: false
        }]
      end
    end

    []
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
