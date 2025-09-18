class RestaurantsController < ApplicationController
  before_action :require_authentication
  
  def create
    @contact_errors = []
    
    ActiveRecord::Base.transaction do
      # Create restaurant
      @restaurant = current_user.restaurants.build(restaurant_params)
      
      unless @restaurant.save
        render json: { 
          success: false, 
          errors: @restaurant.errors.full_messages 
        }, status: :unprocessable_entity
        return
      end
      
      # Create notification contacts
      
      # Create WhatsApp contacts (skip if they already exist)
      if params[:whatsapp_contacts].present?
        params[:whatsapp_contacts].each do |contact_value|
          normalized_value = contact_value.strip
          # Check if contact already exists for this restaurant
          existing_contact = @restaurant.notification_contacts.find_by(
            contact_type: 'whatsapp', 
            contact_value: normalized_value
          )
          
          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: 'whatsapp',
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
            contact_type: 'telegram', 
            contact_value: normalized_value
          )
          
          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: 'telegram',
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
            contact_type: 'email', 
            contact_value: normalized_value
          )
          
          unless existing_contact
            contact = @restaurant.notification_contacts.build(
              contact_type: 'email',
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
      errors: @contact_errors.presence || ["An error occurred while creating the restaurant"] 
    }, status: :unprocessable_entity
  end
  
  private
  
  def restaurant_params
    params.require(:restaurant).permit(:name, :grab_url, :gojek_url, :address, :phone, :cuisine_type)
  end
end