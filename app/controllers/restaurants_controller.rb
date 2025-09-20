class RestaurantsController < ApplicationController
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
    @contact_errors = []
    @created_restaurants = []

    ActiveRecord::Base.transaction do
      # Check if we have multiple URLs - create separate restaurants for each platform
      grab_url = params.dig(:restaurant, :grab_url) || params[:grab_url]
      gojek_url = params.dig(:restaurant, :gojek_url) || params[:gojek_url]

      if grab_url.blank? && gojek_url.blank?
        render json: {
          success: false,
          errors: [ "At least one platform URL (Grab or GoJek) is required" ]
        }, status: :unprocessable_entity
        return
      end

      # Create Grab restaurant if URL provided
      if grab_url.present?
        grab_restaurant = create_platform_restaurant("grab", grab_url)
        @created_restaurants << grab_restaurant if grab_restaurant
      end

      # Create GoJek restaurant if URL provided
      if gojek_url.present?
        gojek_restaurant = create_platform_restaurant("gojek", gojek_url)
        @created_restaurants << gojek_restaurant if gojek_restaurant
      end

      if @created_restaurants.empty?
        @contact_errors << "Failed to create any restaurants"
        raise ActiveRecord::Rollback
      end

      # Create notification contacts for all created restaurants
      @created_restaurants.each do |restaurant|
        create_notification_contacts(restaurant)

        # Validate that restaurant has required contacts
        unless restaurant.has_required_contacts?
          @contact_errors << "At least one WhatsApp or Telegram contact is required for #{restaurant.platform_name} restaurant"
        end
      end

      if @contact_errors.any?
        raise ActiveRecord::Rollback
      end

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

      render json: {
        success: true,
        message: "Restaurant(s) and notification contacts added successfully!",
        restaurants: restaurants_data,
        redirect_url: dashboard_path
      }
    end
  rescue => e
    Rails.logger.error "Error creating restaurant: #{e.message}"
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
    # Get data from parser first
    parser_data = get_parser_data(platform, platform_url)
    return nil unless parser_data

    # Build restaurant with parsed data
    restaurant_attrs = {
      platform: platform,
      platform_url: platform_url,
      name: parser_data[:name] || params.dig(:restaurant, :name),
      address: parser_data[:address] || params.dig(:restaurant, :address),
      phone: parser_data[:phone] || params.dig(:restaurant, :phone),
      image_url: parser_data[:image_url] || params.dig(:restaurant, :image_url)
    }

    restaurant = current_user.restaurants.build(restaurant_attrs)

    # Set coordinates if available
    if parser_data[:coordinates]
      restaurant.set_coordinates(parser_data[:coordinates][:latitude], parser_data[:coordinates][:longitude])
    end

    # Set cuisines from parsed data or params
    cuisines = parser_data[:cuisines].presence || params[:cuisines]
    if cuisines.present?
      restaurant.set_cuisines(cuisines)
    end

    unless restaurant.save
      @contact_errors.concat(restaurant.errors.full_messages)
      return nil
    end

    # Create working hours if provided
    working_hours = parser_data[:working_hours].presence || params[:working_hours]
    if working_hours.present?
      create_working_hours(restaurant, working_hours)
    end

    restaurant
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
    # Create WhatsApp contacts
    if params[:whatsapp_contacts].present?
      params[:whatsapp_contacts].each do |contact_value|
        create_contact(restaurant, "whatsapp", contact_value.strip)
      end
    end

    # Create Telegram contacts
    if params[:telegram_contacts].present?
      params[:telegram_contacts].each do |contact_value|
        create_contact(restaurant, "telegram", contact_value.strip)
      end
    end

    # Create Email contacts
    if params[:email_contacts].present?
      params[:email_contacts].each do |contact_value|
        create_contact(restaurant, "email", contact_value.strip)
      end
    end
  end

  def create_contact(restaurant, contact_type, contact_value)
    # Check if contact already exists for this restaurant
    existing_contact = restaurant.notification_contacts.find_by(
      contact_type: contact_type,
      contact_value: contact_value
    )

    return if existing_contact

    contact = restaurant.notification_contacts.build(
      contact_type: contact_type,
      contact_value: contact_value
    )

    unless contact.save
      @contact_errors.concat(contact.errors.full_messages)
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
