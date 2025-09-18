class DevController < ApplicationController
  layout false  # Отключаем Rails layout для dev страниц

  def test
  end

  def dashboard
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
