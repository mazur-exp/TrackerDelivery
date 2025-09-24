class DevController < ApplicationController
  layout false  # Отключаем Rails layout для dev страниц

  def test
  end

  def dashboard
    if current_user
      @restaurants = current_user.restaurants.includes(:notification_contacts, :working_hours, :restaurant_status_checks)
      @total_restaurants = @restaurants.count
      @average_rating = calculate_average_rating(@restaurants)
    else
      @restaurants = []
      @total_restaurants = 0
      @average_rating = 0
    end
  end

  private

  def calculate_average_rating(restaurants)
    return 0 if restaurants.empty?
    
    ratings = restaurants.map(&:rating).compact.reject { |r| r == "NEW" || r.blank? }
    return 0 if ratings.empty?
    
    numeric_ratings = ratings.map(&:to_f).reject(&:zero?)
    return 0 if numeric_ratings.empty?
    
    (numeric_ratings.sum / numeric_ratings.size).round(1)
  end

  def onboarding
    if current_user
      # Pre-populate existing contacts for logged-in users
      @existing_whatsapp_contacts = current_user.all_whatsapp_contacts
      @existing_telegram_contacts = current_user.all_telegram_contacts
      @existing_email_contacts = current_user.all_email_contacts
      # Check if user already has restaurants
      @user_has_restaurants = current_user.has_restaurants?

      # Отладочная информация
      Rails.logger.info "=== ONBOARDING DEBUG ==="
      Rails.logger.info "User ID: #{current_user.id}"
      Rails.logger.info "User has restaurants: #{@user_has_restaurants}"
      Rails.logger.info "Restaurants count: #{current_user.restaurants.count}"
      Rails.logger.info "WhatsApp contacts: #{@existing_whatsapp_contacts.inspect}"
      Rails.logger.info "Telegram contacts: #{@existing_telegram_contacts.inspect}"
      Rails.logger.info "Email contacts: #{@existing_email_contacts.inspect}"
      Rails.logger.info "========================"
    end
  end
end
