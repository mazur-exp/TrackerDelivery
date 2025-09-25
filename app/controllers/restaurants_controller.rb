class RestaurantsController < ApplicationController
  Rails.logger.info "=== RestaurantsController loaded at #{Time.current} ==="
  
  before_action :require_authentication, except: [ :extract_data, :extract_gojek_data, :extract_grab_data ]
  skip_before_action :verify_authenticity_token, only: [ :extract_data, :extract_gojek_data, :extract_grab_data ]

  def extract_data
    grab_url = params[:grab_url]
    gojek_url = params[:gojek_url]

    if grab_url.blank? && gojek_url.blank?
      render json: {
        success: false,
        errors: [ "At least one URL must be provided" ]
      }, status: :unprocessable_entity
      return
    end

    parser = RestaurantParserService.new
    result = parser.parse_restaurant_data(grab_url: grab_url, gojek_url: gojek_url)

    if result[:success]
      data = result[:data]

      # Prepare platforms array and platform data
      platforms = []
      platform_data = {}

      if grab_url.present? && data[:platform_data][:grab]
        platforms << "grab"
        grab_data = data[:platform_data][:grab]
        platform_data["grab"] = {
          platform_url: grab_url,
          name: grab_data[:name],
          address: grab_data[:address],
          cuisines: grab_data[:cuisines],
          rating: grab_data[:rating],
          working_hours: format_working_hours_for_frontend(grab_data[:working_hours] || []),
          image_url: grab_data[:image_url],
          status: grab_data[:status] || data[:status]
        }
      end

      if gojek_url.present? && data[:platform_data][:gojek]
        platforms << "gojek"
        gojek_data = data[:platform_data][:gojek]
        platform_data["gojek"] = {
          platform_url: gojek_url,
          name: gojek_data[:name],
          address: gojek_data[:address],
          cuisines: gojek_data[:cuisines],
          rating: gojek_data[:rating],
          working_hours: format_working_hours_for_frontend(gojek_data[:working_hours] || []),
          image_url: gojek_data[:image_url],
          status: gojek_data[:status] || data[:status]
        }
      end

      render json: {
        success: true,
        platforms: platforms,
        platform_data: platform_data,
        merged_data: {
          name: data[:name],
          address: data[:address],
          cuisines: data[:cuisines],
          rating: data[:rating],
          working_hours: format_working_hours_for_frontend(data[:working_hours]),
          image_url: data[:image_url],
          status: data[:status]
        }
      }
    else
      render json: {
        success: false,
        errors: result[:errors] || [ "Failed to extract restaurant data" ]
      }, status: :unprocessable_entity
    end
  end

  def extract_gojek_data
    gojek_url = params[:gojek_url]

    if gojek_url.blank?
      render json: {
        success: false,
        errors: [ "GoJek URL is required" ]
      }, status: :unprocessable_entity
      return
    end

    begin
      start_time = Time.current
      Rails.logger.info "=== GoJek Individual Parser Starting ==="

      gojek_data = GojekParserService.new.parse(gojek_url)

      if gojek_data
        elapsed_time = Time.current - start_time
        Rails.logger.info "GoJek parsing completed in #{elapsed_time}s"

        render json: {
          success: true,
          platform: "gojek",
          data: {
            name: gojek_data[:name],
            address: gojek_data[:address],
            cuisines: gojek_data[:cuisines],
            rating: gojek_data[:rating],
            working_hours: format_working_hours_for_frontend(gojek_data[:working_hours] || []),
            image_url: gojek_data[:image_url],
            status: gojek_data[:status]
          }
        }
      else
        render json: {
          success: false,
          platform: "gojek",
          errors: [ "Failed to extract GoJek restaurant data" ]
        }, status: :unprocessable_entity
      end
    rescue => e
      elapsed_time = Time.current - start_time
      Rails.logger.error "GoJek parsing failed after #{elapsed_time}s: #{e.class} - #{e.message}"
      render json: {
        success: false,
        platform: "gojek",
        errors: [ "GoJek parsing failed: #{e.message}" ]
      }, status: :unprocessable_entity
    end
  end

  def extract_grab_data
    grab_url = params[:grab_url]

    if grab_url.blank?
      render json: {
        success: false,
        errors: [ "Grab URL is required" ]
      }, status: :unprocessable_entity
      return
    end

    begin
      start_time = Time.current
      Rails.logger.info "=== Grab Individual Parser Starting ==="

      grab_data = GrabParserService.new.parse(grab_url)

      if grab_data
        elapsed_time = Time.current - start_time
        Rails.logger.info "Grab parsing completed in #{elapsed_time}s"

        render json: {
          success: true,
          platform: "grab",
          data: {
            name: grab_data[:name],
            address: grab_data[:address],
            coordinates: grab_data[:coordinates],
            cuisines: grab_data[:cuisines],
            rating: grab_data[:rating],
            working_hours: format_working_hours_for_frontend(grab_data[:working_hours] || []),
            image_url: grab_data[:image_url],
            status: grab_data[:status]
          }
        }
      else
        render json: {
          success: false,
          platform: "grab",
          errors: [ "Failed to extract Grab restaurant data" ]
        }, status: :unprocessable_entity
      end
    rescue => e
      elapsed_time = Time.current - start_time
      Rails.logger.error "Grab parsing failed after #{elapsed_time}s: #{e.class} - #{e.message}"
      render json: {
        success: false,
        platform: "grab",
        errors: [ "Grab parsing failed: #{e.message}" ]
      }, status: :unprocessable_entity
    end
  end

  def create
    Rails.logger.info "=== Restaurant Creation Started ==="
    Rails.logger.info "Received params: #{params.inspect}"
    
    @contact_errors = []
    @created_restaurants = []

    ActiveRecord::Base.transaction do
      Rails.logger.info "Starting database transaction"
      
      # Handle new platform-specific data format
      platforms_data = params[:platforms]
      Rails.logger.info "Platforms data: #{platforms_data.inspect}"
      
      # Backward compatibility - check for old format
      if platforms_data.blank?
        Rails.logger.info "Using backward compatibility mode"
        grab_url = params.dig(:restaurant, :grab_url) || params[:grab_url]
        gojek_url = params.dig(:restaurant, :gojek_url) || params[:gojek_url]
        Rails.logger.info "Grab URL: #{grab_url}, GoJek URL: #{gojek_url}"

        if grab_url.blank? && gojek_url.blank?
          Rails.logger.error "No platform URLs provided in backward compatibility mode"
          render json: {
            success: false,
            errors: [ "At least one platform URL (Grab or GoJek) is required" ]
          }, status: :unprocessable_entity
          return
        end

        # Create restaurants using old method (fallback)
        if grab_url.present?
          Rails.logger.info "Creating Grab restaurant via old method"
          grab_restaurant = create_platform_restaurant("grab", grab_url)
          @created_restaurants << grab_restaurant if grab_restaurant
          Rails.logger.info "Grab restaurant creation result: #{grab_restaurant ? 'SUCCESS' : 'FAILED'}"
        end

        if gojek_url.present?
          Rails.logger.info "Creating GoJek restaurant via old method"
          gojek_restaurant = create_platform_restaurant("gojek", gojek_url)
          @created_restaurants << gojek_restaurant if gojek_restaurant
          Rails.logger.info "GoJek restaurant creation result: #{gojek_restaurant ? 'SUCCESS' : 'FAILED'}"
        end
      else
        # New platform-specific data format
        Rails.logger.info "Creating restaurants with platform-specific data: #{platforms_data.keys.join(', ')}"
        
        platforms_data.each do |platform, platform_data|
          Rails.logger.info "Creating #{platform} restaurant with data: #{platform_data[:name]}"
          Rails.logger.info "Platform data details: #{platform_data.inspect}"
          
          restaurant = create_platform_restaurant_with_data(platform, platform_data)
          @created_restaurants << restaurant if restaurant
          Rails.logger.info "#{platform.capitalize} restaurant creation result: #{restaurant ? 'SUCCESS' : 'FAILED'}"
        end
      end

      Rails.logger.info "Created restaurants count: #{@created_restaurants.count}"
      Rails.logger.info "Created restaurants: #{@created_restaurants.map { |r| "#{r.name} (#{r.platform})" }.join(', ')}"
      
      if @created_restaurants.empty?
        Rails.logger.error "No restaurants created - triggering rollback"
        @contact_errors << "Failed to create any restaurants"
        raise ActiveRecord::Rollback
      end

      # Create notification contacts for all created restaurants
      Rails.logger.info "Creating notification contacts for #{@created_restaurants.count} restaurants"
      @created_restaurants.each do |restaurant|
        Rails.logger.info "Creating contacts for restaurant: #{restaurant.name} (#{restaurant.platform})"
        create_notification_contacts(restaurant)

        # Validate that restaurant has required contacts
        unless restaurant.has_required_contacts?
          error_msg = "At least one WhatsApp or Telegram contact is required for #{restaurant.platform_name} restaurant"
          Rails.logger.error error_msg
          @contact_errors << error_msg
        end
      end

      Rails.logger.info "Contact errors count: #{@contact_errors.count}"
      Rails.logger.info "Contact errors: #{@contact_errors}" if @contact_errors.any?
      
      if @contact_errors.any?
        Rails.logger.error "Contact errors detected - triggering rollback"
        raise ActiveRecord::Rollback
      end

      Rails.logger.info "All validation passed - preparing success response"
      
      # Prepare response data
      restaurants_data = @created_restaurants.map do |restaurant|
        {
          id: restaurant.id,
          name: restaurant.name,
          platform: restaurant.platform,
          platform_url: restaurant.platform_url,
          address: restaurant.address,
          coordinates: restaurant.coordinates_hash,
          contacts: {
            whatsapp: restaurant.all_whatsapp_contacts,
            telegram: restaurant.all_telegram_contacts,
            email: restaurant.all_email_contacts
          }
        }
      end

      Rails.logger.info "Transaction completed successfully - rendering success response"
      render json: {
        success: true,
        message: "Restaurant(s) and notification contacts added successfully!",
        restaurants: restaurants_data,
        redirect_url: dashboard_path
      }
    end
  rescue => e
    Rails.logger.error "=== EXCEPTION CAUGHT IN RESTAURANT CREATION ==="
    Rails.logger.error "Exception class: #{e.class}"
    Rails.logger.error "Exception message: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    Rails.logger.error "Contact errors at exception: #{@contact_errors.inspect}"
    
    render json: {
      success: false,
      errors: @contact_errors.presence || [ "An error occurred while creating the restaurant" ]
    }, status: :unprocessable_entity
  end

  private

  def restaurant_params
    params.require(:restaurant).permit(:name, :platform, :platform_url, :address, :phone, :image_url, :coordinates)
  end

  def create_platform_restaurant(platform, platform_url)
    Rails.logger.info "Creating #{platform} restaurant with URL: #{platform_url}"
    
    # Use data from params (frontend has already parsed the data)
    # Only fallback to parser if no data provided (backward compatibility)
    restaurant_attrs = {
      platform: platform,
      platform_url: platform_url,
      name: params.dig(:restaurant, :name),
      address: params.dig(:restaurant, :address),
      phone: params.dig(:restaurant, :phone),
      image_url: params.dig(:restaurant, :image_url)
    }

    # If no data in params, fallback to parser (for API calls without frontend parsing)
    if restaurant_attrs[:name].blank?
      Rails.logger.info "No restaurant data in params, falling back to parser for #{platform}"
      parser_data = get_parser_data(platform, platform_url)
      return nil unless parser_data

      restaurant_attrs.merge!({
        name: parser_data[:name],
        address: parser_data[:address],
        phone: parser_data[:phone],
        image_url: parser_data[:image_url]
      })

      # Use parser data for subsequent operations
      cuisines_data = parser_data[:cuisines]
      working_hours_data = parser_data[:working_hours]
      coordinates_data = parser_data[:coordinates]
    else
      Rails.logger.info "Using restaurant data from frontend for #{platform}: #{restaurant_attrs[:name]}"
      # Use data from params (frontend parsing)
      cuisines_data = params[:cuisines]
      working_hours_data = params[:working_hours]
      coordinates_data = params.dig(:restaurant, :coordinates)
    end

    restaurant = current_user.restaurants.build(restaurant_attrs)

    # Set coordinates if available
    if coordinates_data.present?
      if coordinates_data.is_a?(Hash) && coordinates_data[:latitude] && coordinates_data[:longitude]
        restaurant.set_coordinates(coordinates_data[:latitude], coordinates_data[:longitude])
      elsif coordinates_data.is_a?(String)
        # Handle coordinate string format (latitude, longitude)
        coords = coordinates_data.split(',').map(&:strip)
        if coords.length == 2
          restaurant.set_coordinates(coords[0].to_f, coords[1].to_f)
        end
      end
    end

    # Set cuisines
    if cuisines_data.present?
      restaurant.set_cuisines(cuisines_data)
    end

    unless restaurant.save
      Rails.logger.error "Failed to save restaurant: #{restaurant.errors.full_messages}"
      @contact_errors.concat(restaurant.errors.full_messages)
      return nil
    end

    Rails.logger.info "Successfully saved restaurant: #{restaurant.name} (ID: #{restaurant.id})"

    # Create working hours if provided
    if working_hours_data.present?
      create_working_hours(restaurant, working_hours_data)
    end

    restaurant
  end

  def create_platform_restaurant_with_data(platform, platform_data)
    Rails.logger.info "=== Creating #{platform} restaurant with provided data ==="
    Rails.logger.info "Platform data keys: #{platform_data.keys}"
    Rails.logger.info "Restaurant name: #{platform_data[:name]}"
    
    # Build restaurant attributes from provided platform data
    restaurant_attrs = {
      platform: platform,
      platform_url: platform_data[:platform_url],
      name: platform_data[:name],
      address: platform_data[:address],
      phone: platform_data[:phone],
      image_url: platform_data[:image_url],
      rating: platform_data[:rating],
    }
    Rails.logger.info "Restaurant attributes: #{restaurant_attrs}"

    restaurant = current_user.restaurants.build(restaurant_attrs)
    Rails.logger.info "Built restaurant object: #{restaurant.inspect}"

    # Set coordinates if available
    coordinates_data = platform_data[:coordinates]
    Rails.logger.info "Coordinates data: #{coordinates_data}"
    if coordinates_data.present?
      if coordinates_data.is_a?(Hash) && coordinates_data[:latitude] && coordinates_data[:longitude]
        Rails.logger.info "Setting coordinates: #{coordinates_data[:latitude]}, #{coordinates_data[:longitude]}"
        restaurant.set_coordinates(coordinates_data[:latitude], coordinates_data[:longitude])
      elsif coordinates_data.is_a?(String)
        # Handle coordinate string format (latitude, longitude)
        coords = coordinates_data.split(',').map(&:strip)
        if coords.length == 2
          Rails.logger.info "Setting coordinates from string: #{coords[0]}, #{coords[1]}"
          restaurant.set_coordinates(coords[0].to_f, coords[1].to_f)
        end
      end
    end

    # Set cuisines
    cuisines_data = platform_data[:cuisines]
    Rails.logger.info "Cuisines data: #{cuisines_data}"
    if cuisines_data.present?
      Rails.logger.info "Setting cuisines: #{cuisines_data}"
      restaurant.set_cuisines(cuisines_data)
    end

    Rails.logger.info "Attempting to save restaurant..."
    unless restaurant.save
      Rails.logger.error "Failed to save #{platform} restaurant: #{restaurant.errors.full_messages}"
      Rails.logger.error "Restaurant validation errors: #{restaurant.errors.messages}"
      @contact_errors.concat(restaurant.errors.full_messages)
      return nil
    end

    Rails.logger.info "Successfully saved #{platform} restaurant: #{restaurant.name} (ID: #{restaurant.id})"

    # Create working hours if provided
    working_hours_data = platform_data[:working_hours]
    Rails.logger.info "Working hours data: #{working_hours_data}"
    if working_hours_data.present?
      Rails.logger.info "Creating working hours for restaurant"
      create_working_hours(restaurant, working_hours_data)
    end

    # Create initial status check record from parsing data
    status_data = platform_data[:status]
    Rails.logger.info "Status data: #{status_data}"
    if status_data.present?
      Rails.logger.info "Creating initial status check for restaurant"
      create_initial_status_check(restaurant, status_data)
    end

    Rails.logger.info "=== Completed creating #{platform} restaurant ==="
    restaurant
  end

  def create_initial_status_check(restaurant, status_data)
    return unless status_data.is_a?(Hash) && status_data[:status_text].present?
    
    # Map parser status to database status
    actual_status = case status_data[:status_text]
    when 'open'
      'open'
    when 'closed', 'temporarily_closed'
      'closed'
    else
      'unknown'
    end
    
    # Get expected status from restaurant's working hours
    expected_status = restaurant.expected_status_at(Time.current) rescue 'unknown'
    
    # Determine if this is an anomaly
    is_anomaly = (expected_status == 'open' && actual_status == 'closed') ||
                 (expected_status == 'closed' && actual_status == 'open')
    
    # Create the status check record
    restaurant.restaurant_status_checks.create!(
      checked_at: Time.current,
      actual_status: actual_status,
      expected_status: expected_status,
      is_anomaly: is_anomaly,
      parser_response: status_data.to_json
    )
    
    Rails.logger.info "Created initial status check for #{restaurant.name}: #{actual_status} (expected: #{expected_status})"
  rescue => e
    Rails.logger.error "Failed to create initial status check: #{e.message}"
  end

  def get_parser_data(platform, platform_url)
    begin
      case platform
      when "grab"
        GrabParserService.new.parse(platform_url)
      when "gojek"
        GojekParserService.new.parse(platform_url)
      else
        nil
      end
    rescue => e
      Rails.logger.error "Failed to parse #{platform} data: #{e.message}"
      nil
    end
  end

  def create_notification_contacts(restaurant)
    Rails.logger.info "=== Creating notification contacts for #{restaurant.name} ==="
    Rails.logger.info "WhatsApp contacts param: #{params[:whatsapp_contacts].inspect}"
    Rails.logger.info "Telegram contacts param: #{params[:telegram_contacts].inspect}"
    Rails.logger.info "Email contacts param: #{params[:email_contacts].inspect}"
    
    # Create WhatsApp contacts
    if params[:whatsapp_contacts].present?
      Rails.logger.info "Creating #{params[:whatsapp_contacts].count} WhatsApp contacts"
      params[:whatsapp_contacts].each do |contact_value|
        Rails.logger.info "Creating WhatsApp contact: #{contact_value.strip}"
        create_contact(restaurant, "whatsapp", contact_value.strip)
      end
    end

    # Create Telegram contacts
    if params[:telegram_contacts].present?
      Rails.logger.info "Creating #{params[:telegram_contacts].count} Telegram contacts"
      params[:telegram_contacts].each do |contact_value|
        Rails.logger.info "Creating Telegram contact: #{contact_value.strip}"
        create_contact(restaurant, "telegram", contact_value.strip)
      end
    end

    # Create Email contacts
    if params[:email_contacts].present?
      Rails.logger.info "Creating #{params[:email_contacts].count} Email contacts"
      params[:email_contacts].each do |contact_value|
        Rails.logger.info "Creating Email contact: #{contact_value.strip}"
        create_contact(restaurant, "email", contact_value.strip)
      end
    end
    
    Rails.logger.info "=== Completed creating contacts for #{restaurant.name} ==="
  end

  def create_contact(restaurant, contact_type, contact_value)
    Rails.logger.info "Creating #{contact_type} contact: #{contact_value} for restaurant #{restaurant.name}"
    
    # Check if contact already exists for this restaurant
    existing_contact = restaurant.notification_contacts.find_by(
      contact_type: contact_type,
      contact_value: contact_value
    )

    if existing_contact
      Rails.logger.info "Contact already exists, skipping: #{contact_type} - #{contact_value}"
      return
    end

    contact = restaurant.notification_contacts.build(
      contact_type: contact_type,
      contact_value: contact_value
    )

    unless contact.save
      Rails.logger.error "Failed to save #{contact_type} contact #{contact_value}: #{contact.errors.full_messages}"
      @contact_errors.concat(contact.errors.full_messages)
    else
      Rails.logger.info "Successfully created #{contact_type} contact: #{contact_value}"
    end
  end

  def format_working_hours_for_frontend(working_hours)
    working_hours.map do |wh|
      {
        day_of_week: wh[:day_of_week],
        day_name: WorkingHour::DAYS_OF_WEEK[wh[:day_of_week]],
        opens_at: wh[:opens_at],
        closes_at: wh[:closes_at],
        break_start: wh[:break_start],
        break_end: wh[:break_end],
        is_closed: wh[:is_closed]
      }
    end
  end

  def create_working_hours(restaurant, working_hours_data)
    working_hours_data.each do |wh_data|
      restaurant.working_hours.create!(
        day_of_week: wh_data[:day_of_week],
        opens_at: wh_data[:opens_at],
        closes_at: wh_data[:closes_at],
        break_start: wh_data[:break_start],
        break_end: wh_data[:break_end],
        is_closed: wh_data[:is_closed] || false
      )
    end
  rescue => e
    Rails.logger.error "Error creating working hours: #{e.message}"
    @contact_errors << "Failed to save working hours"
  end
end
