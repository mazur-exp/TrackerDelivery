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
    end
  end
end
