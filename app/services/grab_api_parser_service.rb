require "httparty"
require "http-cookie"
require "json"

class GrabApiParserService
  include HTTParty

  base_uri "https://portal.grab.com/foodweb/guest/v2"

  def initialize
    @timeout = 20  # Increased for Finland → Singapore network latency
    @cookies_file = Rails.root.join("grab_cookies.json")
    load_credentials
  end

  def parse(url)
    Rails.logger.info "=== Grab API Parser (JWT) Starting for URL: #{url} ==="
    start_time = Time.current

    return nil if url.blank?

    # Extract merchant ID from URL
    merchant_id = extract_merchant_id(url)
    unless merchant_id
      Rails.logger.error "Grab API: Could not extract merchant ID from URL"
      return nil
    end

    Rails.logger.info "Grab API: Merchant ID: #{merchant_id}"

    # Check JWT available
    unless @jwt_token
      Rails.logger.error "Grab API: No JWT token available! Check grab_cookies.json"
      return nil
    end

    begin
      # Make API request with JWT
      api_url = "/merchants/#{merchant_id}"
      params = { latlng: "-8.6705,115.2126" }  # Bali coordinates

      headers = build_headers

      Rails.logger.info "Grab API: Making request to #{api_url}..."
      response = self.class.get(api_url, {
        query: params,
        headers: headers,
        timeout: @timeout
      })

      if response.success?
        Rails.logger.info "Grab API: Success! Got #{response.body.length} chars"
        data = extract_data_from_api(response.parsed_response)

        duration = Time.current - start_time
        Rails.logger.info "Grab API: Parsing completed in #{duration.round(2)}s"

        return data
      else
        Rails.logger.error "Grab API: HTTP #{response.code}: #{response.message}"
        return nil
      end

    rescue => e
      duration = Time.current - start_time
      Rails.logger.error "Grab API: Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      return nil
    end
  end

  private

  def load_credentials
    # Try storage path first (writable by rails user), then root
    storage_file = Rails.root.join("storage", "grab_cookies.json") rescue nil
    if storage_file && File.exist?(storage_file)
      @cookies_file = storage_file
    end

    unless File.exist?(@cookies_file)
      Rails.logger.warn "Grab API: grab_cookies.json not found"
      @jwt_token = nil
      @api_version = nil
      @cookies = {}
      return
    end

    data = JSON.parse(File.read(@cookies_file))
    @jwt_token = data["jwt_token"]
    @api_version = data["api_version"] || "uaf6yDMWlVv0CaTK5fHdB"
    @cookies = data["cookies"] || {}

    Rails.logger.info "Grab API: Loaded #{@cookies.size} cookies, JWT: #{@jwt_token ? 'present' : 'MISSING'}"
  rescue => e
    Rails.logger.error "Grab API: Error loading credentials: #{e.message}"
    @jwt_token = nil
    @api_version = nil
    @cookies = {}
  end

  def build_headers
    cookie_string = @cookies.map { |k, v| "#{k}=#{v}" }.join("; ")

    {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      "Accept" => "application/json, text/plain, */*",
      "Accept-Language" => "en-US,en;q=0.9,id;q=0.8",
      "X-Hydra-JWT" => @jwt_token,
      "X-Grab-Web-App-Version" => @api_version,
      "X-Country-Code" => "ID",
      "X-GFC-Country" => "ID",
      "Cookie" => cookie_string,
      "Referer" => "https://food.grab.com/",
      "Origin" => "https://food.grab.com"
    }
  end

  def extract_merchant_id(url)
    # Handle both short and long URLs
    # https://r.grab.com/g/6-20250920_..._6-C65ZV62KVNEDPE
    # https://food.grab.com/id/en/restaurant/online-delivery/6-C65ZV62KVNEDPE

    # Merchant ID format: 6- followed by UPPERCASE letters and numbers
    # Use last match to skip date (6-20250920)
    matches = url.scan(/6-[A-Z0-9]+/)
    return matches.last if matches.any?

    nil
  end

  def extract_data_from_api(api_response)
    merchant = api_response["merchant"]

    unless merchant
      Rails.logger.error "Grab API: No merchant data in API response"
      return nil
    end

    # Extract cuisines (comma-separated string!)
    cuisines = []
    if merchant["cuisine"] && !merchant["cuisine"].empty?
      cuisines = merchant["cuisine"].split(",").map(&:strip).first(3)
    end

    # Extract coordinates
    coordinates = nil
    if merchant["latlng"]
      coordinates = {
        latitude: merchant["latlng"]["latitude"]&.to_f,
        longitude: merchant["latlng"]["longitude"]&.to_f
      }
    end

    # Extract opening hours
    opening_hours = extract_opening_hours(merchant["openingHours"])

    # Extract status
    status = extract_status(merchant["openingHours"])

    # Address
    address = merchant["address"] || merchant["shortAddress"]

    {
      name: merchant["name"],
      address: address,
      rating: merchant["rating"]&.to_s,
      review_count: merchant["reviewCount"],
      cuisines: cuisines,
      coordinates: coordinates,
      image_url: merchant["photoHref"],
      status: status,
      opening_hours: opening_hours,
      working_hours: opening_hours,  # Backward compatibility with old parser
      distance_km: merchant["distanceInKm"]
    }.compact
  end

  def extract_opening_hours(opening_hours_data)
    return [] unless opening_hours_data

    days = []
    day_names = {
      "sun" => { full: "Sunday", short: "Minggu", order: 7 },
      "mon" => { full: "Monday", short: "Senin", order: 1 },
      "tue" => { full: "Tuesday", short: "Selasa", order: 2 },
      "wed" => { full: "Wednesday", short: "Rabu", order: 3 },
      "thu" => { full: "Thursday", short: "Kamis", order: 4 },
      "fri" => { full: "Friday", short: "Jumat", order: 5 },
      "sat" => { full: "Saturday", short: "Sabtu", order: 6 }
    }

    day_names.each do |key, info|
      if opening_hours_data[key]
        hours_str = opening_hours_data[key]
        parsed = parse_hours_string(hours_str)

        if parsed
          # day_of_week: 0=Sunday, 1=Monday, ...6=Saturday (for UI compatibility)
          day_of_week_index = info[:order] == 7 ? 0 : info[:order]

          days << {
            day: info[:order],
            day_name: info[:short],
            day_name_en: info[:full],
            start_time: parsed[:start_time],
            end_time: parsed[:end_time],
            formatted: "#{info[:short]}: #{parsed[:start_time]}-#{parsed[:end_time]}",
            # UI compatibility fields:
            day_of_week: day_of_week_index,
            opens_at: parsed[:start_time],
            closes_at: parsed[:end_time],
            is_closed: false
          }
        end
      end
    end

    days.sort_by { |d| d[:day] }
  end

  def parse_hours_string(hours_str)
    return nil unless hours_str

    match = hours_str.match(/(\d+):(\d+)(am|pm)-(\d+):(\d+)(am|pm)/i)
    return nil unless match

    start_hour = match[1].to_i
    start_min = match[2]
    start_period = match[3].downcase
    end_hour = match[4].to_i
    end_min = match[5]
    end_period = match[6].downcase

    # Convert to 24-hour format
    start_hour = 0 if start_hour == 12 && start_period == "am"
    start_hour += 12 if start_period == "pm" && start_hour != 12

    end_hour = 0 if end_hour == 12 && end_period == "am"
    end_hour += 12 if end_period == "pm" && end_hour != 12

    {
      start_time: format("%02d:%02d", start_hour, start_min.to_i),
      end_time: format("%02d:%02d", end_hour, end_min.to_i)
    }
  end

  def extract_status(opening_hours_data)
    return { is_open: nil, status_text: "unknown", error: "No opening hours data" } unless opening_hours_data

    is_open = opening_hours_data["open"] == true

    {
      is_open: is_open,
      status_text: is_open ? "open" : "closed",
      displayed_hours: opening_hours_data["displayedHours"],
      error: nil
    }
  end
end
