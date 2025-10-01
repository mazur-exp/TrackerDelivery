class DashboardsController < ApplicationController
  layout false  # Отключаем Rails layout для dashboard страниц
  # Убираем allow_unauthenticated_access - onboarding требует авторизации для автозаполнения

  def show
    if current_user
      @restaurants = current_user.restaurants
        .includes(:notification_contacts, :working_hours, :restaurant_status_checks)
        .ordered_by_status
      @total_restaurants = @restaurants.count
      @average_rating = calculate_average_rating(@restaurants)
    else
      @restaurants = []
      @total_restaurants = 0
      @average_rating = 0
    end
  end

  def onboarding
    if current_user
      # Pre-populate existing contacts for logged-in users
      @existing_whatsapp_contacts = current_user.all_whatsapp_contacts
      @existing_telegram_contacts = current_user.all_telegram_contacts  
      @existing_email_contacts = current_user.all_email_contacts
      @user_has_restaurants = current_user.has_restaurants?
    else
      # Initialize empty arrays for non-logged in users
      @existing_whatsapp_contacts = []
      @existing_telegram_contacts = []
      @existing_email_contacts = []
      @user_has_restaurants = false
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
end