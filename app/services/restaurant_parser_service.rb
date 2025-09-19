class RestaurantParserService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def parse_restaurant_data(grab_url: nil, gojek_url: nil)
    start_time = Time.current
    Rails.logger.info "=== Restaurant Parser Starting ==="
    Rails.logger.info "URLs - Grab: #{grab_url.present?}, GoJek: #{gojek_url.present?}"

    data = {
      name: nil,
      address: nil,
      cuisines: [],
      working_hours: [],
      rating: nil,
      image_url: nil,
      platform_data: {}
    }

    begin
      # Parse Grab data with retry
      if grab_url.present?
        Rails.logger.info "Parsing Grab URL: #{grab_url}"
        grab_data = parse_with_retry("Grab", grab_url) do
          GrabParserService.new.parse(grab_url)
        end
        merge_platform_data(data, grab_data, :grab) if grab_data
      end

      # Parse GoJek data with retry
      if gojek_url.present?
        Rails.logger.info "Parsing GoJek URL: #{gojek_url}"
        gojek_data = parse_with_retry("GoJek", gojek_url) do
          GojekParserService.new.parse(gojek_url)
        end
        merge_platform_data(data, gojek_data, :gojek) if gojek_data
      end

      # Normalize and validate data
      normalize_data(data)

      total_time = Time.current - start_time
      Rails.logger.info "=== Restaurant Parser Completed in #{total_time}s ==="

      # Check if we have minimal required data
      if data[:name].blank? && data[:address].blank?
        @errors << "Could not extract basic restaurant information from any platform"
        return { success: false, errors: @errors }
      end

      { success: true, data: data }
    rescue => e
      total_time = Time.current - start_time
      Rails.logger.error "Fatal error parsing restaurant data after #{total_time}s: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
      @errors << "Failed to parse restaurant data: #{e.message}"
      { success: false, errors: @errors }
    end
  end

  private

  def parse_with_retry(platform_name, url, max_retries: 2)
    retries = 0

    begin
      start_time = Time.current
      result = yield

      if result
        Rails.logger.info "#{platform_name}: Parsing successful in #{Time.current - start_time}s"
        result
      else
        Rails.logger.warn "#{platform_name}: Parsing returned nil"
        nil
      end

    rescue => e
      retries += 1
      elapsed_time = Time.current - start_time

      Rails.logger.warn "#{platform_name}: Parsing failed (attempt #{retries}/#{max_retries + 1}) after #{elapsed_time}s: #{e.class} - #{e.message}"

      if retries <= max_retries
        wait_time = retries * 2 # 2, 4 seconds
        Rails.logger.info "#{platform_name}: Retrying in #{wait_time} seconds..."
        sleep(wait_time)

        # Clean up any hanging processes before retry
        begin
          system("pkill -f 'chrome.*--headless' > /dev/null 2>&1") if RUBY_PLATFORM.include?("darwin") || RUBY_PLATFORM.include?("linux")
        rescue
          # Ignore cleanup errors
        end

        retry
      else
        Rails.logger.error "#{platform_name}: All #{max_retries + 1} attempts failed for URL: #{url}"
        @errors << "#{platform_name} parsing failed after #{max_retries + 1} attempts: #{e.message}"
        nil
      end
    end
  end

  def merge_platform_data(data, platform_data, platform_name)
    # Prefer data from the first platform, but merge missing fields
    data[:name] ||= platform_data[:name]
    data[:address] ||= platform_data[:address]
    data[:rating] ||= platform_data[:rating]
    data[:image_url] ||= platform_data[:image_url]

    # Merge cuisines (remove duplicates)
    data[:cuisines] = (data[:cuisines] + platform_data[:cuisines]).uniq.compact

    # Store working hours from both platforms
    if platform_data[:working_hours].present?
      data[:working_hours] = merge_working_hours(data[:working_hours], platform_data[:working_hours])
    end

    # Store platform-specific data
    data[:platform_data][platform_name] = platform_data
  end

  def merge_working_hours(existing_hours, new_hours)
    return new_hours if existing_hours.empty?

    # For now, prefer the first platform's working hours
    # In the future, we could implement smarter merging
    existing_hours.presence || new_hours
  end

  def normalize_data(data)
    # Normalize cuisines - take top 3
    data[:cuisines] = data[:cuisines].first(3)

    # Validate required fields
    if data[:name].blank?
      @errors << "Restaurant name could not be extracted"
    end

    if data[:address].blank?
      @errors << "Restaurant address could not be extracted"
    end
  end
end
