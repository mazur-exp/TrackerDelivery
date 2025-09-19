require "selenium-webdriver"
require "timeout"

class GojekParserService
  TIMEOUT_SECONDS = 20  # Reduced from 30 to prevent hanging

  def parse(url)
    Rails.logger.info "=== GoJek Selenium Parser Starting for URL: #{url} ==="
    return nil if url.blank?

    driver = nil
    start_time = Time.current

    begin
      Timeout.timeout(TIMEOUT_SECONDS) do
        # Setup Chrome with headless options
        driver = setup_chrome_driver
        Rails.logger.info "GoJek: Driver setup completed in #{Time.current - start_time}s"

        Rails.logger.info "GoJek: Navigating to URL with Selenium..."
        navigation_start = Time.current
        driver.get(url)
        Rails.logger.info "GoJek: Navigation completed in #{Time.current - navigation_start}s"

        # Wait for page to load and JavaScript to execute
        Rails.logger.info "GoJek: Waiting for page to load..."
        page_load_start = Time.current
        sleep(2) # Reduced from 3 to 2 seconds

        # Wait for content to appear or redirects to complete
        wait = Selenium::WebDriver::Wait.new(timeout: 8) # Reduced from 10 to 8
        wait.until { driver.execute_script("return document.readyState") == "complete" }
        Rails.logger.info "GoJek: Page load completed in #{Time.current - page_load_start}s"

        # Check if we were redirected to a full GoJek page
        current_url = driver.current_url
        Rails.logger.info "GoJek: Final URL after redirects: #{current_url}"

        # First try to extract data without clicking any buttons
        Rails.logger.info "GoJek: Trying to extract data without modal click..."
        extraction_start = Time.current

        data = {
          name: extract_restaurant_name_selenium(driver),
          address: extract_address_selenium(driver, skip_modal: true),
          cuisines: extract_cuisines_selenium(driver),
          working_hours: extract_working_hours_selenium(driver, skip_modal: true),
          rating: extract_rating_selenium(driver),
          image_url: extract_image_url_selenium(driver),
          status: extract_restaurant_status_selenium(driver)
        }

        Rails.logger.info "GoJek: Initial extraction completed in #{Time.current - extraction_start}s"
        Rails.logger.info "GoJek: Initial data: name=#{data[:name].present?}, address=#{data[:address].present?}, working_hours=#{data[:working_hours]&.any?}"

        # If address or working hours are missing, try clicking the info button
        if data[:address].blank? || data[:working_hours].blank?
          Rails.logger.info "GoJek: Address or working hours missing, trying modal click..."
          modal_start = Time.current

          if click_restaurant_info_button(driver)
            Rails.logger.info "GoJek: Modal click successful, re-extracting data..."
            # Re-extract missing data after modal opens
            data[:address] = extract_address_selenium(driver, skip_modal: false) if data[:address].blank?
            data[:working_hours] = extract_working_hours_selenium(driver, skip_modal: false) if data[:working_hours].blank?
            Rails.logger.info "GoJek: Modal extraction completed in #{Time.current - modal_start}s"
          else
            Rails.logger.warn "GoJek: Modal click failed or button not found"
          end
        end

        total_time = Time.current - start_time
        Rails.logger.info "GoJek: Total parsing time: #{total_time}s"
        Rails.logger.info "GoJek: Final extracted data: #{data.inspect}"
        data
      end
    rescue Timeout::Error
      total_time = Time.current - start_time
      Rails.logger.error "GoJek: Timeout after #{total_time}s while parsing URL: #{url}"
      nil
    rescue => e
      total_time = Time.current - start_time
      Rails.logger.error "GoJek: Error after #{total_time}s parsing URL #{url}: #{e.class} - #{e.message}"
      Rails.logger.error "GoJek: Backtrace: #{e.backtrace.first(5).join("\n")}"
      nil
    ensure
      cleanup_start = Time.current
      cleanup_driver(driver)
      Rails.logger.info "GoJek: Browser cleanup completed in #{Time.current - cleanup_start}s"
    end
  end

  private

  def cleanup_driver(driver)
    return unless driver

    begin
      # Try graceful quit first
      driver.quit
    rescue => e
      Rails.logger.warn "GoJek: Error during graceful driver quit: #{e.message}"

      begin
        # Force close if graceful quit fails
        driver.close
      rescue => e2
        Rails.logger.warn "GoJek: Error during driver close: #{e2.message}"
      end

      # Kill any remaining Chrome processes as last resort
      begin
        system("pkill -f 'chrome.*--headless' > /dev/null 2>&1") if RUBY_PLATFORM.include?("darwin") || RUBY_PLATFORM.include?("linux")
      rescue => e3
        Rails.logger.warn "GoJek: Error killing Chrome processes: #{e3.message}"
      end
    end
  end

  def click_restaurant_info_button(driver)
    Rails.logger.info "=== Attempting to click restaurant info button ==="

    # Check if modal is already open
    existing_modal = driver.find_elements(:css, "div.rounded-2xl.pointer-events-auto")
    if existing_modal.any?
      Rails.logger.info "Modal already open, no need to click"
      return true
    end

    begin
      # Look for clickable elements that might open the info modal
      # Try SVG path elements with the arrow pattern
      arrow_elements = driver.find_elements(:css, 'svg path[d*="M8.297 6.71a1 1 0 0 1 1.406-1.42l5.954 5.89"]')

      if arrow_elements.any?
        Rails.logger.info "Found #{arrow_elements.length} arrow SVG elements"

        # Check if element is clickable and visible
        arrow_parent = arrow_elements.first.find_element(:xpath, "../..")
        if arrow_parent.displayed? && arrow_parent.enabled?
          arrow_parent.click
          Rails.logger.info "Clicked arrow element, waiting for modal to appear..."
          sleep(1.5) # Reduced wait time

          # Verify modal appeared
          modal_appeared = driver.find_elements(:css, "div.rounded-2xl.pointer-events-auto").any?
          Rails.logger.info "Modal appeared: #{modal_appeared}"
          return modal_appeared
        else
          Rails.logger.info "Arrow element not clickable or visible"
        end
      end

      # Alternative: look for any clickable element near restaurant name
      clickable_selectors = [
        "button[aria-expanded]",
        '[role="button"]',
        'div[class*="cursor-pointer"]',
        'div[class*="clickable"]',
        'button[type="button"]'
      ]

      clickable_selectors.each do |selector|
        elements = driver.find_elements(:css, selector)
        Rails.logger.info "Found #{elements.length} elements with selector: #{selector}"

        elements.each_with_index do |element, i|
          begin
            if element.displayed? && element.enabled?
              Rails.logger.info "Trying to click element #{i} with selector: #{selector}"
              element.click
              sleep(1) # Reduced wait time

              # Check if modal appeared
              modal_appeared = driver.find_elements(:css, "div.rounded-2xl.pointer-events-auto").any?
              if modal_appeared
                Rails.logger.info "Modal appeared after clicking element #{i}"
                return true
              end
            end
          rescue => e
            Rails.logger.info "Failed to click element #{i}: #{e.message}"
          end
        end
      end

    rescue => e
      Rails.logger.warn "Error clicking restaurant info button: #{e.message}"
    end

    Rails.logger.info "=== No clickable info button found or modal did not appear ==="
    false
  end

  def setup_chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new

    # Essential headless mode flags for production servers
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-software-rasterizer")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--remote-debugging-port=9223")

    # Performance and stability improvements
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-plugins")
    options.add_argument("--disable-images")
    # NOTE: JavaScript is required for GoJek SPA
    options.add_argument("--disable-web-security")
    options.add_argument("--disable-features=VizDisplayCompositor")
    options.add_argument("--disable-background-timer-throttling")
    options.add_argument("--disable-renderer-backgrounding")
    options.add_argument("--disable-backgrounding-occluded-windows")
    options.add_argument("--memory-pressure-off")
    options.add_argument("--max_old_space_size=4096")
    
    # Additional flags for Chromium compatibility
    options.add_argument("--disable-blink-features=AutomationControlled")

    # Timeout settings
    options.add_argument("--page-load-strategy=eager") # Don't wait for all resources

    # Set binary path (for Docker containers)
    chrome_binary = ENV['CHROME_BIN'] || 
                   (File.exist?("/usr/bin/google-chrome-stable") ? "/usr/bin/google-chrome-stable" : "/usr/bin/chromium")

    # User agent to avoid detection (adapt for browser type)
    if chrome_binary&.include?("chromium")
      options.add_argument("--user-agent=Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    else
      options.add_argument("--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    end
    
    if File.exist?(chrome_binary)
      options.binary = chrome_binary
      Rails.logger.info "GoJek: Using Chrome binary: #{chrome_binary}"
    else
      Rails.logger.warn "GoJek: No Chrome binary found at expected locations"
    end

    # Set ChromeDriver path if specified
    if ENV['CHROMEDRIVER_PATH'] && File.exist?(ENV['CHROMEDRIVER_PATH'])
      Rails.logger.info "GoJek: Using ChromeDriver: #{ENV['CHROMEDRIVER_PATH']}"
    end

    Rails.logger.info "GoJek: Starting Chrome driver with optimized settings for production"

    # Explicitly set ChromeDriver service if path is specified
    if ENV['CHROMEDRIVER_PATH'] && File.exist?(ENV['CHROMEDRIVER_PATH'])
      service = Selenium::WebDriver::Service.chrome(path: ENV['CHROMEDRIVER_PATH'])
      Rails.logger.info "GoJek: Using explicit ChromeDriver service: #{ENV['CHROMEDRIVER_PATH']}"
      driver = Selenium::WebDriver.for(:chrome, service: service, options: options)
    else
      driver = Selenium::WebDriver.for(:chrome, options: options)
    end
    driver.manage.timeouts.page_load = 15 # 15 seconds max for page load
    driver.manage.timeouts.script_timeout = 10 # 10 seconds max for script execution

    driver
  rescue => e
    Rails.logger.error "GoJek: Failed to setup Chrome driver: #{e.message}"
    raise
  end

  def extract_restaurant_name_selenium(driver)
    # First try to find restaurant name in modal title (from your HTML structure)
    # <h2 class="text-gf-content-primary gf-label-l flex items-center text-lg" id="headlessui-dialog-title-:r5:" data-headlessui-state="open">Eat Street, Canggu</h2>
    begin
      modal_title = driver.find_elements(:css, "h2.text-gf-content-primary.gf-label-l")
      Rails.logger.info "Found #{modal_title.length} modal title elements"

      modal_title.each_with_index do |element, i|
        text = element.text.strip
        Rails.logger.info "Modal title #{i}: '#{text}'"

        if text.present? && text.length > 3
          return text
        end
      end
    rescue => e
      Rails.logger.info "Error searching modal title: #{e.message}"
    end

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

  def extract_address_selenium(driver, skip_modal: false)
    Rails.logger.info "=== Extracting Address (skip_modal: #{skip_modal}) ==="

    # First try to find address on main page without modal
    if skip_modal
      # Look for address elements directly on the page
      begin
        # Try the exact modal structure selector first (sometimes modal content is on main page)
        main_modal_address = driver.find_elements(:css, "div.text-gf-content-muted.gf-body-s")
        Rails.logger.info "Found #{main_modal_address.length} potential address divs on main page"

        main_modal_address.each_with_index do |element, i|
          text = element.text.strip
          Rails.logger.info "Main page address div #{i}: '#{text}'"

          # Check if this looks like an address (contains location indicators)
          if text.length > 20 &&
             (text.downcase.include?("jl.") || text.downcase.include?("jl ") || text.downcase.include?("street") ||
              text.downcase.include?("canggu") || text.downcase.include?("bali") ||
              text.downcase.include?("kec.") || text.downcase.include?("regency") ||
              text.downcase.include?("ubud") || text.downcase.include?("denpasar") ||
              text.downcase.include?("badung") || text.downcase.include?("seminyak") ||
              text.downcase.include?("gang") || text.downcase.include?("kuta utara") ||
              text.downcase.include?("kuta selatan"))
            Rails.logger.info "Found address on main page: #{text}"
            return text
          end
        end

        # Fallback: Try various other selectors on main page
        main_page_selectors = [
          'font[dir="auto"]',
          'div[dir="auto"]',
          'p[dir="auto"]',
          'span[dir="auto"]'
        ]

        main_page_selectors.each do |selector|
          elements = driver.find_elements(:css, selector)
          Rails.logger.info "Found #{elements.length} elements with selector #{selector}"

          elements.each_with_index do |element, i|
            text = element.text.strip
            Rails.logger.info "Main page element #{i}: '#{text}'"

            # Check if this looks like an address (contains location indicators)
            if text.length > 20 &&
               (text.downcase.include?("jl.") || text.downcase.include?("jl ") || text.downcase.include?("street") ||
                text.downcase.include?("canggu") || text.downcase.include?("bali") ||
                text.downcase.include?("kec.") || text.downcase.include?("regency") ||
                text.downcase.include?("ubud") || text.downcase.include?("denpasar") ||
                text.downcase.include?("badung") || text.downcase.include?("seminyak") ||
                text.downcase.include?("gang") || text.downcase.include?("kuta utara") ||
                text.downcase.include?("kuta selatan"))
              Rails.logger.info "Found address on main page: #{text}"
              return text
            end
          end
        end
      rescue => e
        Rails.logger.info "Error searching main page address: #{e.message}"
      end
    end

    # If skip_modal is false, try modal elements
    unless skip_modal
      begin
        # Look for the exact address structure in modal based on your HTML
        # The address is in: <div class="text-gf-content-muted gf-body-s">Jl. Semat Raya, Gang Jalak 21, Canggu, Bali</div>
        modal_address_elements = driver.find_elements(:css, "div.text-gf-content-muted.gf-body-s")
        Rails.logger.info "Found #{modal_address_elements.length} modal address elements"

        modal_address_elements.each_with_index do |element, i|
          text = element.text.strip
          Rails.logger.info "Modal address element #{i}: '#{text}'"

          # Check if this looks like an address (contains location indicators)
          if text.length > 10 &&
             (text.downcase.include?("jl.") || text.downcase.include?("jl ") || text.downcase.include?("street") ||
              text.downcase.include?("canggu") || text.downcase.include?("bali") ||
              text.downcase.include?("kec.") || text.downcase.include?("regency") ||
              text.downcase.include?("ubud") || text.downcase.include?("denpasar") ||
              text.downcase.include?("badung") || text.downcase.include?("seminyak") ||
              text.downcase.include?("gang") || text.downcase.include?("kuta utara") ||
              text.downcase.include?("kuta selatan"))
            Rails.logger.info "Found address in modal: #{text}"
            return text
          end
        end
      rescue => e
        Rails.logger.info "Error searching modal address: #{e.message}"
      end
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
      cuisine_elements = driver.find_elements(:css, "p.text-gf-content-secondary.line-clamp-1")
      Rails.logger.info "GoJek: Found #{cuisine_elements.length} potential cuisine elements"

      # Also try alternative selectors
      alt_elements = driver.find_elements(:css, 'p[class*="text-gf-content-secondary"]')
      Rails.logger.info "GoJek: Found #{alt_elements.length} alternative elements"

      # Try looking for any p elements that might contain cuisines
      all_p_elements = driver.find_elements(:css, "p")
      cuisine_candidates = all_p_elements.select { |p|
        text = p.text.strip
        text.include?(",") && text.length > 5 && text.length < 100
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
        elsif text.include?(",") && text.length > 10 && text.length < 50
          # If it contains commas, check if it's a list of cuisine categories
          Rails.logger.info "GoJek: Checking comma-separated text for cuisine categories"

          # Skip obvious non-cuisine text
          next if text_normalized.include?("canggu") || text_normalized.include?("street") ||
                  text_normalized.include?("eat street") || text_normalized.include?("restaurant") ||
                  text_normalized.include?("promo") || text_normalized == restaurant_name&.downcase

          # Split by commas and check each part
          text.split(",").each do |part|
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
          if text.include?(",") && text.length > 10 && text.length < 100
            # Skip location-based names
            next if text.downcase.include?("canggu") || text.downcase.include?("street") ||
                    text.downcase.include?("eat street") || text.downcase.include?("restaurant")

            # Check if any known cuisine categories are present
            known_cuisines = %w[aneka nasi bakmie ayam bebek bakso soto barat cepat saji chinese india indonesia jajanan jepang kopi korea makanan sehat martabak minuman nasi goreng pizza pasta roti sate seafood steak sweets thailand timur tengah]
            text_words = text.downcase.split(/[,\s&]+/).map(&:strip)
            has_known_cuisine = known_cuisines.any? { |cuisine| text_words.include?(cuisine) }

            if has_known_cuisine
              Rails.logger.info "GoJek: Alternative text contains known cuisine categories"
              text.split(",").each do |cuisine|
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
          if text.include?(",") && text.length > 5 && text.length < 100
            # Skip if it looks like a restaurant name, food items, or contains unwanted text
            next if text.downcase.include?("only eggs") ||
                    text.downcase.include?("restaurant") ||
                    text.downcase.include?("super partner") ||
                    text.downcase.include?("soto") ||        # Skip food items like "Soto Daging Sapi"
                    text.downcase.include?("daging") ||      # Skip meat dishes
                    text.downcase.include?("sambal") ||      # Skip sauce/condiment names
                    text.downcase.include?("goreng") ||      # Skip fried dishes
                    text.downcase.include?("dan ") ||        # Skip Indonesian "and" - indicates food description
                    text.include?("\n") # Skip multiline text that might contain "Super Partner\nBarat"

            # Split by commas and clean up
            text.split(",").each do |cuisine|
              cleaned = cuisine.strip.downcase
              # Filter out non-cuisine terms
              next if cleaned.include?("super partner") ||
                      cleaned.include?("partner") ||
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
        elements = driver.find_elements(:css, "p, div, span")
        elements.each do |element|
          text = element.text.strip

          # Look for text that might be cuisines
          if text.match?(/^[A-Za-z\s,&]+$/) && text.include?(",") &&
             text.length > 10 && text.length < 50 &&
             !text.downcase.include?("only eggs") &&
             !text.downcase.include?("restaurant") &&
             !text.downcase.include?("super partner") &&
             !text.downcase.include?("soto") &&
             !text.downcase.include?("daging") &&
             !text.downcase.include?("sambal") &&
             !text.downcase.include?("goreng") &&
             !text.downcase.include?("dan ") &&
             !text.include?("\n")

            text.split(",").each do |cuisine|
              cleaned = cuisine.strip
              # Filter out non-cuisine terms
              next if cleaned.downcase.include?("super partner") ||
                      cleaned.downcase.include?("partner") ||
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
      p_elements = driver.find_elements(:css, "p")
      Rails.logger.info "Found #{p_elements.length} p elements"

      p_elements.each_with_index do |p, i|
        text = p.text.strip
        classes = p.attribute("class").to_s

        if text.match?(/^\d+(\.\d+)?$/) && classes.match?(/gf|label/i)
          rating = text.to_f
          Rails.logger.info "Found potential rating P#{i}: text='#{text}' classes='#{classes}' rating=#{rating}"

          if rating >= 1.0 && rating <= 5.0
            # Check if parent has SVG
            parent = p.find_element(:xpath, "..")
            has_svg = !parent.find_elements(:css, "svg").empty?
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
          container = svg.find_element(:xpath, "../..")
          elements = container.find_elements(:css, "*")

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

  def extract_working_hours_selenium(driver, skip_modal: false)
    Rails.logger.info "=== Extracting Working Hours (skip_modal: #{skip_modal}) ==="
    working_hours = []

    # First try to find working hours on main page without modal
    if skip_modal
      # Look for the exact modal structure on main page (sometimes modal content appears on main page)
      begin
        # Try to find "Jam buka" header and schedule rows directly on main page
        jam_buka_headers = driver.find_elements(:css, "h4.gf-label-m")
        Rails.logger.info "Found #{jam_buka_headers.length} h4 headers on main page"

        jam_buka_headers.each_with_index do |header, i|
          header_text = header.text.strip.downcase
          Rails.logger.info "Main page header #{i}: '#{header_text}'"

          if header_text.include?("jam buka") || header_text.include?("opening hours") || header_text.include?("hours")
            Rails.logger.info "Found hours header on main page, looking for schedule data..."

            # Find schedule rows in the parent container
            parent = header.find_element(:xpath, "..")
            schedule_rows = parent.find_elements(:css, "div.flex.items-center.justify-between")
            Rails.logger.info "Found #{schedule_rows.length} schedule rows on main page"

            schedule_rows.each_with_index do |row, j|
              begin
                day_element = row.find_element(:css, "div.py-2.pr-9.gf-label-s")
                time_element = row.find_element(:css, "div.text-left.gf-body-s")

                day_text = day_element.text.strip
                time_text = time_element.text.strip

                Rails.logger.info "Main page schedule row #{j}: #{day_text} -> #{time_text}"

                # Parse Indonesian day names and times
                day_hours = parse_indonesian_day_hours(day_text, time_text)
                working_hours.concat(day_hours) if day_hours.any?

              rescue => e
                Rails.logger.info "Error parsing main page schedule row #{j}: #{e.message}"
              end
            end

            break if working_hours.any?
          end
        end

        # Fallback: Try to find time patterns in various elements
        if working_hours.empty?
          time_patterns = [
            /\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}/,  # "08:00 - 22:00"
            /\d{1,2}[ap]m\s*-\s*\d{1,2}[ap]m/i,   # "8am - 10pm"
            /open.*\d{1,2}/i,                       # "Open until 22"
            /closes.*\d{1,2}/i                      # "Closes at 10pm"
          ]

          # Search all text elements for time patterns
          all_elements = driver.find_elements(:css, "div, p, span, font")
          Rails.logger.info "Searching #{all_elements.length} elements for time patterns on main page"

          all_elements.each do |element|
            text = element.text.strip
            next if text.length < 5 || text.length > 100

            time_patterns.each do |pattern|
              if text.match?(pattern)
                Rails.logger.info "Found potential time pattern on main page: '#{text}'"
                # Try to parse this as working hours
                hours = parse_simple_hours_text(text)
                if hours.any?
                  working_hours.concat(hours)
                  break
                end
              end
            end

            break if working_hours.any?
          end
        end
      rescue => e
        Rails.logger.info "Error searching main page working hours: #{e.message}"
      end
    end

    # If skip_modal is false or no hours found, try modal
    if working_hours.empty? && !skip_modal
      begin
        # Look for "Jam buka" section in modal based on your HTML structure
        # <h4 class="gf-label-m pb-2">Jam buka</h4>
        opening_hours_headers = driver.find_elements(:css, "h4.gf-label-m")
        Rails.logger.info "Found #{opening_hours_headers.length} h4 headers"

        opening_hours_headers.each_with_index do |header, i|
          header_text = header.text.strip.downcase
          Rails.logger.info "Header #{i}: '#{header_text}'"

          if header_text.include?("jam buka") || header_text.include?("opening hours") || header_text.include?("hours")
            Rails.logger.info "Found opening hours header, looking for schedule data..."

            # Find the parent container with schedule data
            parent = header.find_element(:xpath, "..")
            schedule_rows = parent.find_elements(:css, "div.flex.items-center.justify-between")
            Rails.logger.info "Found #{schedule_rows.length} schedule rows"

            schedule_rows.each_with_index do |row, j|
              begin
                Rails.logger.info "Processing schedule row #{j}..."
                
                # Try multiple selectors for day element
                day_element = nil
                day_selectors = [
                  "div.py-2.pr-9.gf-label-s",
                  "div[class*='gf-label-s']",
                  "div[class*='py-2']",
                  "div:first-child"
                ]
                
                day_selectors.each do |selector|
                  elements = row.find_elements(:css, selector)
                  if elements.any?
                    day_element = elements.first
                    Rails.logger.info "Found day element with selector: #{selector}"
                    break
                  end
                end
                
                # Try multiple selectors for time element  
                time_element = nil
                time_selectors = [
                  "div.text-left.gf-body-s",
                  "div[class*='gf-body-s']", 
                  "div[class*='text-left']",
                  "div:last-child",
                  "div:nth-child(2)"
                ]
                
                time_selectors.each do |selector|
                  elements = row.find_elements(:css, selector)
                  if elements.any?
                    time_element = elements.first
                    Rails.logger.info "Found time element with selector: #{selector}"
                    break
                  end
                end
                
                # If specific selectors fail, try to get text from child divs
                if day_element.nil? || time_element.nil?
                  all_divs = row.find_elements(:css, "div")
                  Rails.logger.info "Row #{j} has #{all_divs.length} div elements, trying fallback"
                  
                  if all_divs.length >= 2
                    day_element = all_divs[0] if day_element.nil?
                    time_element = all_divs[1] if time_element.nil?
                    Rails.logger.info "Using fallback: first div for day, second div for time"
                  end
                end

                if day_element && time_element
                  day_text = day_element.text.strip
                  time_text = time_element.text.strip

                  Rails.logger.info "Schedule row #{j}: #{day_text} -> #{time_text}"

                  # Parse Indonesian day names and times
                  day_hours = parse_indonesian_day_hours(day_text, time_text)
                  working_hours.concat(day_hours) if day_hours.any?
                else
                  Rails.logger.warn "Could not find day or time elements in row #{j}"
                  
                  # Last resort: try to parse row text directly
                  row_text = row.text.strip
                  Rails.logger.info "Row #{j} full text: '#{row_text}'"
                  
                  # Try to split by common patterns
                  if row_text.include?("\t")
                    parts = row_text.split("\t")
                  elsif row_text.include?("  ") # Two spaces
                    parts = row_text.split("  ").map(&:strip).reject(&:empty?)
                  else
                    parts = []
                  end
                  
                  if parts.length >= 2
                    day_text = parts[0].strip
                    time_text = parts[1].strip
                    Rails.logger.info "Parsed from row text: #{day_text} -> #{time_text}"
                    
                    day_hours = parse_indonesian_day_hours(day_text, time_text)
                    working_hours.concat(day_hours) if day_hours.any?
                  end
                end

              rescue => e
                Rails.logger.warn "Error parsing schedule row #{j}: #{e.class} - #{e.message}"
                Rails.logger.info "Row #{j} HTML: #{row.attribute('outerHTML')[0..200]}..." rescue "Could not get HTML"
              end
            end

            break if working_hours.any?
          end
        end
      rescue => e
        Rails.logger.info "Error extracting modal working hours: #{e.message}"
      end
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
      restaurant_images = driver.find_elements(:css, "img.object-cover")
      Rails.logger.info "Found #{restaurant_images.length} images with object-cover class"

      restaurant_images.each_with_index do |img, i|
        src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
        alt_text = img.attribute("alt").to_s
        width = img.attribute("width")
        height = img.attribute("height")
        fetchpriority = img.attribute("fetchpriority")
        data_nimg = img.attribute("data-nimg")

        Rails.logger.info "Image #{i}: src='#{src}' alt='#{alt_text}' width='#{width}' height='#{height}'"

        next unless src.present?

        # Check if it's the restaurant avatar (usually has dimensions like 98x98, high priority, etc.)
        if (width == "98" && height == "98") ||
           (fetchpriority == "high") ||
           (data_nimg == "1" && alt_text.length > 10)

          # Check if it's a GoJek image URL
          if src.include?("gojekapi.com") || src.include?("gofood") || src.include?("darkroom")
            # Convert relative URLs to absolute
            src = src.start_with?("http") ? src : "https:#{src}"
            if src.match?(/\.(jpg|jpeg|png|webp)/i)
              Rails.logger.info "Found restaurant avatar: #{src}"
              return src
            end
          end
        end
      end

      # Fallback: find any img with GoJek characteristics
      all_images = driver.find_elements(:css, "img")
      Rails.logger.info "Fallback: Found #{all_images.length} total images"

      all_images.each_with_index do |img, i|
        src = img.attribute("src") || img.attribute("data-src") || img.attribute("data-lazy-src")
        next unless src.present?

        Rails.logger.info "Fallback image #{i}: #{src}"

        # Check if it's a GoJek image URL
        if src.include?("gojekapi.com") || src.include?("gofood") || src.include?("darkroom")
          # Convert relative URLs to absolute
          src = src.start_with?("http") ? src : "https:#{src}"
          if src.match?(/\.(jpg|jpeg|png|webp)/i)
            Rails.logger.info "Found GoJek image: #{src}"
            return src
          end
        end

        # Check for other indicators it's a restaurant image
        alt_text = img.attribute("alt").to_s.downcase
        if (img.attribute("data-nimg") == "1" || img.attribute("fetchpriority") == "high") &&
           (alt_text.include?("restaurant") || alt_text.include?("eggs") || alt_text.length > 10)
          src = src.start_with?("http") ? src : "https:#{src}"
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

  def extract_restaurant_status_selenium(driver)
    Rails.logger.info "=== Extracting Restaurant Status ==="
    
    begin
      # Search for "Tutup" text across all elements
      all_elements = driver.find_elements(:css, "*")
      tutup_found = false
      opening_info = nil
      
      all_elements.each do |element|
        text = element.text.strip rescue ""
        next if text.empty? || text.length > 100
        
        text_lower = text.downcase
        
        # Check for "Tutup" (closed) indicator
        if text_lower.include?("tutup")
          Rails.logger.info "Found Tutup indicator: '#{text}'"
          tutup_found = true
          
          # Try to extract opening time information
          if text_lower.include?("buka")
            opening_info = text
            Rails.logger.info "Found opening info: '#{opening_info}'"
          end
          
          break
        end
        
        # Also check for "Buka hari" + day pattern (even without "Tutup")
        if text_lower.include?("buka hari")
          # List of Indonesian weekdays
          indonesian_days = ["senin", "selasa", "rabu", "kamis", "jumat", "sabtu", "minggu"]
          
          # Check if any day of week is mentioned
          if indonesian_days.any? { |day| text_lower.include?(day) }
            Rails.logger.info "Found 'Buka hari [day]' pattern (closed): '#{text}'"
            tutup_found = true
            opening_info = text
            Rails.logger.info "Found opening info: '#{opening_info}'"
            break
          end
        end
      end
      
      if tutup_found
        status = {
          is_open: false,
          status_text: "closed",
          opening_info: opening_info,
          raw_status: opening_info || "Tutup"
        }
        Rails.logger.info "Restaurant Status: CLOSED - #{opening_info || 'Tutup'}"
        return status
      else
        status = {
          is_open: true,
          status_text: "open",
          opening_info: nil,
          raw_status: "Open"
        }
        Rails.logger.info "Restaurant Status: OPEN"
        return status
      end
      
    rescue => e
      Rails.logger.warn "Error extracting restaurant status: #{e.message}"
      # Default to unknown status
      return {
        is_open: nil,
        status_text: "unknown",
        opening_info: nil,
        raw_status: "Status unknown"
      }
    end
  end

  def parse_simple_hours_text(text)
    Rails.logger.info "Parsing simple hours text: '#{text}'"
    hours = []

    # Pattern for time range like "08:00 - 22:00" or "8am - 10pm"
    time_range_pattern = /(\d{1,2}):?(\d{0,2})\s*(am|pm)?\s*[-–]\s*(\d{1,2}):?(\d{0,2})\s*(am|pm)?/i
    match = text.match(time_range_pattern)

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
        # Assume this applies to all days (common for simple displays)
        (0..6).each do |day|
          hours << {
            day_of_week: day,
            opens_at: format_time(start_hour, start_min),
            closes_at: format_time(end_hour, end_min),
            is_closed: false
          }
        end
        Rails.logger.info "Parsed time range: #{format_time(start_hour, start_min)} - #{format_time(end_hour, end_min)}"
      end
    end

    hours
  end

  def parse_indonesian_day_hours(day_text, time_text)
    Rails.logger.info "Parsing Indonesian day hours: '#{day_text}' -> '#{time_text}'"

    # Map Indonesian day names to day numbers (0 = Monday)
    indonesian_day_mapping = {
      "senin" => 0,    # Monday
      "selasa" => 1,   # Tuesday
      "rabu" => 2,     # Wednesday
      "kamis" => 3,    # Thursday
      "jumat" => 4,    # Friday
      "sabtu" => 5,    # Saturday
      "minggu" => 6    # Sunday
    }

    day_num = indonesian_day_mapping[day_text.downcase.strip]
    return [] if day_num.nil?

    # Parse time (check for closed status)
    if time_text.downcase.include?("tutup") || time_text.downcase.include?("closed") || time_text.downcase.include?("close")
      return [ {
        day_of_week: day_num,
        opens_at: nil,
        closes_at: nil,
        is_closed: true
      } ]
    end

    # Check for complex schedule with breaks (like "08:00-12:00 & 17:00-22:00")
    if time_text.include?("&") || time_text.include?(" & ")
      Rails.logger.info "Found complex schedule with break: '#{time_text}'"
      
      # Split by & and process each time range
      time_ranges = time_text.split(/\s*&\s*/).map(&:strip)
      working_hours = []
      
      time_ranges.each_with_index do |range, i|
        Rails.logger.info "Processing time range #{i}: '#{range}'"
        
        # Parse individual time range like "08:00-12:00"
        range_parts = range.split("-").map(&:strip)
        if range_parts.length == 2
          opens_at = range_parts[0]
          closes_at = range_parts[1]
          
          # Validate time format
          if opens_at.match?(/^\d{1,2}:\d{2}$/) && closes_at.match?(/^\d{1,2}:\d{2}$/)
            # For the first range, use normal working hours
            # For subsequent ranges, we'll store as break_start/break_end or separate entries
            if i == 0
              working_hours << {
                day_of_week: day_num,
                opens_at: opens_at,
                closes_at: closes_at,
                is_closed: false
              }
            else
              # For now, create a separate entry for the second shift
              # In the future, you might want to enhance the model to support breaks
              working_hours << {
                day_of_week: day_num,
                opens_at: opens_at,
                closes_at: closes_at,
                is_closed: false
              }
            end
          end
        end
      end
      
      Rails.logger.info "Parsed complex schedule into #{working_hours.length} entries"
      return working_hours
    end

    # Parse simple time range like "10:00-21:00"
    time_parts = time_text.split("-").map(&:strip)
    if time_parts.length == 2
      opens_at = time_parts[0]
      closes_at = time_parts[1]

      # Validate time format
      if opens_at.match?(/^\d{1,2}:\d{2}$/) && closes_at.match?(/^\d{1,2}:\d{2}$/)
        return [ {
          day_of_week: day_num,
          opens_at: opens_at,
          closes_at: closes_at,
          is_closed: false
        } ]
      end
    end

    Rails.logger.warn "Could not parse time format: '#{time_text}'"
    []
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
    if time_text.downcase.include?("closed") || time_text.downcase.include?("close")
      return [ {
        day_of_week: day_num,
        opens_at: nil,
        closes_at: nil,
        is_closed: true
      } ]
    end

    # Parse time range like "07:00-23:00"
    time_parts = time_text.split("-").map(&:strip)
    if time_parts.length == 2
      opens_at = time_parts[0]
      closes_at = time_parts[1]

      # Validate time format
      if opens_at.match?(/^\d{2}:\d{2}$/) && closes_at.match?(/^\d{2}:\d{2}$/)
        return [ {
          day_of_week: day_num,
          opens_at: opens_at,
          closes_at: closes_at,
          is_closed: false
        } ]
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
    images = doc.css("img")

    images.each do |img|
      src = img["src"] || img["data-src"] || img["data-lazy-src"]
      next unless src.present?

      # Check if it's a GoJek image URL
      if src.include?("gojekapi.com") || src.include?("gofood")
        # Convert relative URLs to absolute
        src = src.start_with?("http") ? src : "https:#{src}"
        return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
      end

      # Check for other indicators it's a restaurant image
      alt_text = img["alt"].to_s.downcase
      if (img["data-nimg"] == "1" || img["fetchpriority"] == "high") &&
         (alt_text.include?("restaurant") || alt_text.include?("eggs") || alt_text.length > 10)
        src = src.start_with?("http") ? src : "https:#{src}"
        return src if src.match?(/\.(jpg|jpeg|png|webp)/i)
      end
    end

    nil
  end
end
