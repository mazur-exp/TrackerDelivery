# frozen_string_literal: true

class TelegramAuthController < ApplicationController
  skip_before_action :require_authentication, only: [:webhook, :auth_with_token]
  skip_forgery_protection only: [:webhook]

  # POST /auth/telegram/webhook
  # Handles incoming messages from Telegram Bot
  def webhook
    Rails.logger.info "📨 Received Telegram webhook: #{params.inspect}"

    begin
      # Telegram sends the update wrapped in params
      update_params = params.permit!.to_h
      message = update_params["message"]

      if message && message["text"]&.start_with?('/start')
        telegram_user = message["from"]

        # Extract session_token from /start command
        # Format: /start session_token_here OR /start signup_session_token
        start_param = message["text"].split[1]

        # Check if this is a signup flow
        is_signup = start_param&.start_with?('signup_')
        session_token = is_signup ? start_param.sub('signup_', '') : start_param

        Rails.logger.info "📱 Processing /start from user #{telegram_user['id']}, session: #{session_token}, signup: #{is_signup}"

        # Extract locale from session_token (format: locale_token or just token)
        user_locale = :en
        if session_token&.start_with?('ru_')
          user_locale = :ru
          session_token = session_token.sub('ru_', '')
        end

        bot_service = TelegramBotService.new
        bot_service.handle_message(
          telegram_user["id"],
          telegram_user["username"],
          telegram_user["first_name"],
          telegram_user["last_name"],
          session_token,
          is_signup,
          user_locale
        )

        Rails.logger.info "✅ Webhook processed successfully"
      else
        Rails.logger.info "ℹ️  Ignoring non-start message"
      end
    rescue => e
      Rails.logger.error "❌ Webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    head :ok
  end

  # GET /auth/telegram/:token
  # Handles one-time token authentication
  def auth_with_token
    token = params[:token]
    user = User.find_by(auth_token: token)

    if user.nil?
      redirect_to login_path, alert: I18n.t('auth.invalid_link')
      return
    end

    if user.auth_token_expires_at < Time.current
      redirect_to login_path, alert: I18n.t('auth.link_expired')
      return
    end

    # Check if this is a new user (for thank you message)
    is_new_user = user.sessions.empty?

    # Broadcast authentication success via Action Cable
    if user.session_token.present?
      ActionCable.server.broadcast(
        "auth_#{user.session_token}",
        {
          authenticated: true,
          redirect_url: after_authentication_url(user)
        }
      )
      Rails.logger.info "📡 Broadcasting auth success to session: #{user.session_token}"
    end

    # Send thank you message to Telegram
    begin
      bot_service = TelegramBotService.new
      user_locale = (user.locale || I18n.locale).to_sym
      bot_service.send_thank_you(user.telegram_id, is_new_user, user_locale)
    rescue => e
      Rails.logger.error "Failed to send thank you message: #{e.message}"
    end

    # Clear the tokens (one-time use)
    user.update(
      auth_token: nil,
      auth_token_expires_at: nil,
      session_token: nil
    )

    # Start session
    start_new_session_for(user)

    redirect_to after_authentication_url(user), notice: I18n.t('auth.welcome', name: user.display_name)
  end

  # Legacy: POST /auth/telegram/callback
  # Handles Telegram Login Widget callback (if still needed)
  def create
    auth_data = telegram_auth_params

    unless valid_telegram_auth?(auth_data)
      Rails.logger.warn "Invalid Telegram authentication attempt: #{auth_data.inspect}"
      redirect_to login_path, alert: "Telegram authentication failed. Please try again."
      return
    end

    # Find or create user by Telegram ID
    user = User.find_or_initialize_by(telegram_id: auth_data["id"])

    if user.new_record?
      # New Telegram user - create account
      user.assign_attributes(
        telegram_username: auth_data["username"],
        telegram_first_name: auth_data["first_name"],
        telegram_last_name: auth_data["last_name"],
        telegram_photo_url: auth_data["photo_url"],
        telegram_auth_date: Time.at(auth_data["auth_date"].to_i)
      )

      unless user.save
        Rails.logger.error "Failed to create Telegram user: #{user.errors.full_messages}"
        redirect_to login_path, alert: "Failed to create account. Please try again."
        return
      end

      Rails.logger.info "✅ New Telegram user created: #{user.telegram_username} (ID: #{user.telegram_id})"
    else
      # Existing user - update Telegram profile data
      user.update(
        telegram_username: auth_data["username"],
        telegram_first_name: auth_data["first_name"],
        telegram_last_name: auth_data["last_name"],
        telegram_photo_url: auth_data["photo_url"],
        telegram_auth_date: Time.at(auth_data["auth_date"].to_i)
      )

      Rails.logger.info "✅ Telegram user logged in: #{user.telegram_username} (ID: #{user.telegram_id})"
    end

    # Start session
    start_new_session_for(user)

    # Optional: Add to notification_contacts if requested and user has restaurants
    if params[:add_to_notifications] == "true" && user.has_restaurants?
      add_telegram_to_notifications(user)
    end

    # Redirect to appropriate page (onboarding or dashboard)
    redirect_to after_authentication_url, notice: "Welcome, #{user.display_name}!"
  end

  private

  def telegram_auth_params
    params.permit(:id, :first_name, :last_name, :username, :photo_url, :auth_date, :hash)
          .to_h
          .stringify_keys
  end

  # Validates Telegram Login Widget data authenticity
  # https://core.telegram.org/widgets/login#checking-authorization
  def valid_telegram_auth?(auth_data)
    return false if auth_data["hash"].blank?

    # Extract hash and build data check string
    received_hash = auth_data.delete("hash")
    data_check_arr = auth_data.sort.map { |k, v| "#{k}=#{v}" }
    data_check_string = data_check_arr.join("\n")

    # Create secret key from bot token
    bot_token = telegram_bot_token
    return false if bot_token.blank?

    secret_key = OpenSSL::Digest::SHA256.digest(bot_token)

    # Calculate hash
    calculated_hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

    # Verify hash matches
    return false unless calculated_hash == received_hash

    # Verify auth is not too old (24 hours)
    auth_time = Time.at(auth_data["auth_date"].to_i)
    return false if Time.current - auth_time > 24.hours

    true
  rescue => e
    Rails.logger.error "Telegram auth validation error: #{e.message}"
    false
  end

  def telegram_bot_token
    # Try Rails credentials first, then ENV
    Rails.application.credentials.dig(:telegram, :bot_token) ||
      ENV["TELEGRAM_BOT_TOKEN"]
  end

  def add_telegram_to_notifications(user)
    # Add Telegram contact to each restaurant if not already present
    user.restaurants.each do |restaurant|
      existing = restaurant.notification_contacts.find_by(
        contact_type: "telegram",
        contact_value: user.telegram_id.to_s
      )

      next if existing

      restaurant.notification_contacts.create!(
        contact_type: "telegram",
        contact_value: user.telegram_id.to_s,
        is_primary: restaurant.notification_contacts.where(contact_type: "telegram").empty?,
        priority_order: restaurant.notification_contacts.maximum(:priority_order).to_i + 1,
        is_active: true
      )

      Rails.logger.info "📱 Added Telegram contact to restaurant: #{restaurant.name}"
    end
  rescue => e
    Rails.logger.error "Failed to add Telegram to notifications: #{e.message}"
    # Don't fail authentication if this fails
  end
end
