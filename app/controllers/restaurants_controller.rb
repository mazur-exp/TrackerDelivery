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

    ActiveRecord::Base.transaction do
      # Create restaurant
      @restaurant = current_user.restaurants.build(restaurant_params)

      # Set cuisines from array
      if params[:cuisines].present?
        @restaurant.set_cuisines(params[:cuisines])
      end

      unless @restaurant.save
        render json: {
          success: false,
          errors: @restaurant.errors.full_messages
        }, status: :unprocessable_entity
        return
      end

      # Create working hours if provided
      if params[:working_hours].present?
        create_working_hours(@restaurant, params[:working_hours])
      end

      # Create notification contacts

      # Create WhatsApp contacts (skip if they already exist)
      if params[:whatsapp_contacts].present?
        params[:whatsapp_contacts].each do |contact_value|
          normalized_value = contact_value.strip
          # Check if contact already exists for this restaurant
          existing_contact = @restaurant.notification_contacts.find_by(
            contact_type: "whatsapp",
            contact_value: normalized_value
          )

          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: "whatsapp",
              contact_value: normalized_value
            )
            unless contact.save
              @contact_errors.concat(contact.errors.full_messages)
            end
          end
        end
      end

      # Create Telegram contacts (skip if they already exist)
      if params[:telegram_contacts].present?
        params[:telegram_contacts].each do |contact_value|
          normalized_value = contact_value.strip
          # Check if contact already exists for this restaurant
          existing_contact = @restaurant.notification_contacts.find_by(
            contact_type: "telegram",
            contact_value: normalized_value
          )

          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: "telegram",
              contact_value: normalized_value
            )
            unless contact.save
              @contact_errors.concat(contact.errors.full_messages)
            end
          end
        end
      end

      # Create Email contacts (skip if they already exist)
      if params[:email_contacts].present?
        params[:email_contacts].each do |contact_value|
          normalized_value = contact_value.strip
          # Check if contact already exists for this restaurant
          existing_contact = @restaurant.notification_contacts.find_by(
            contact_type: "email",
            contact_value: normalized_value
          )

          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: "email",
              contact_value: normalized_value
            )
            unless contact.save
              @contact_errors.concat(contact.errors.full_messages)
            end
          end
        end
      end

      # Validate that restaurant has required contacts
      unless @restaurant.has_required_contacts?
        @contact_errors << "At least one WhatsApp or Telegram contact is required"
      end

      if @contact_errors.any?
        raise ActiveRecord::Rollback
      end

      render json: {
        success: true,
        message: "Restaurant and notification contacts added successfully!",
        restaurant: @restaurant,
        contacts: {
          whatsapp: @restaurant.all_whatsapp_contacts,
          telegram: @restaurant.all_telegram_contacts,
          email: @restaurant.all_email_contacts
        },
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
    params.require(:restaurant).permit(:name, :grab_url, :gojek_url, :address, :phone, :image_url)
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
