class RestaurantParserService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def parse_restaurant_data(grab_url: nil, gojek_url: nil)
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
      if grab_url.present?
        grab_data = GrabParserService.new.parse(grab_url)
        merge_platform_data(data, grab_data, :grab) if grab_data
      end

      if gojek_url.present?
        gojek_data = GojekParserService.new.parse(gojek_url)
        merge_platform_data(data, gojek_data, :gojek) if gojek_data
      end

      # Normalize and validate data
      normalize_data(data)

      { success: true, data: data }
    rescue => e
      Rails.logger.error "Error parsing restaurant data: #{e.message}"
      @errors << "Failed to parse restaurant data: #{e.message}"
      { success: false, errors: @errors }
    end
  end

  private

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
