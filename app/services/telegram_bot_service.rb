# frozen_string_literal: true

class TelegramBotService
  def initialize
    @token = telegram_bot_token
    @base_url = "https://api.telegram.org/bot#{@token}"
  end

  # Handle incoming messages from Telegram
  def handle_message(telegram_user_id, username, first_name, last_name, session_token = nil, is_signup_flow = false, user_locale = :en)
    # Find or create user
    user = User.find_or_initialize_by(telegram_id: telegram_user_id)
    is_new_user = user.new_record?

    if is_new_user
      user.assign_attributes(
        telegram_username: username,
        telegram_first_name: first_name,
        telegram_last_name: last_name,
        locale: user_locale.to_s  # Save user's locale
      )
    else
      # Update user info and locale
      user.update(
        telegram_username: username,
        telegram_first_name: first_name,
        telegram_last_name: last_name,
        locale: user_locale.to_s
      )
    end

    # Generate one-time auth token and session token
    auth_token = SecureRandom.urlsafe_base64(32)
    user.update(
      auth_token: auth_token,
      auth_token_expires_at: 10.minutes.from_now,
      session_token: session_token # For Action Cable broadcast
    )

    # Generate auth URL with locale
    auth_url = Rails.application.routes.url_helpers.telegram_token_auth_url(
      token: auth_token,
      locale: user_locale,
      host: ENV['APP_HOST'] || 'localhost:3000',
      protocol: ENV['APP_PROTOCOL'] || 'http'
    )

    # Send appropriate message based on signup flow or user status
    send_auth_link(telegram_user_id, auth_url, is_new_user, is_signup_flow, user_locale)

    user
  end

  private

  def send_auth_link(telegram_user_id, auth_url, is_new_user, is_signup_flow = false, locale = :en)
    # Show signup message based on database status (not page context)
    # is_new_user = true means telegram_id NOT in database yet
    show_signup_message = is_new_user

    I18n.with_locale(locale) do
      message = if show_signup_message
        "🎉 <b>#{I18n.t('telegram.welcome_new_title')}</b>\n\n" \
        "#{I18n.t('telegram.welcome_new_description')}\n\n" \
        "📍 #{I18n.t('telegram.feature_monitoring')}\n" \
        "⏰ #{I18n.t('telegram.feature_frequency')}\n" \
        "🔔 #{I18n.t('telegram.feature_notifications')}\n\n" \
        "#{I18n.t('telegram.click_to_register')}"
      else
        "👋 <b>#{I18n.t('telegram.welcome_back_title')}</b>\n\n" \
        "#{I18n.t('telegram.click_to_login')}"
      end

      keyboard = {
        inline_keyboard: [[
          {
            text: show_signup_message ? I18n.t('telegram.button_complete_registration') : I18n.t('telegram.button_sign_in'),
            url: auth_url
          }
        ]]
      }

      send_message(telegram_user_id, message, keyboard)
    end
  end

  # Send thank you message after successful authentication
  def send_thank_you(telegram_user_id, is_new_user, locale = :en)
    I18n.with_locale(locale) do
      message = if is_new_user
        "✅ <b>#{I18n.t('telegram.thank_you_new_title')}</b>\n\n" \
        "#{I18n.t('telegram.thank_you_new_features')}\n\n" \
        "#{I18n.t('telegram.thank_you_new_action')}"
      else
        "✅ <b>#{I18n.t('telegram.thank_you_existing_title')}</b>\n\n" \
        "#{I18n.t('telegram.thank_you_existing_action')}"
      end

      send_message(telegram_user_id, message)
    end
  end

  def send_message(chat_id, text, reply_markup = nil)
    params = {
      chat_id: chat_id,
      text: text,
      parse_mode: 'HTML'
    }
    params[:reply_markup] = reply_markup.to_json if reply_markup

    uri = URI("#{@base_url}/sendMessage")

    # Configure Net::HTTP with SSL support
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # Skip SSL verification for development

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(params)

    response = http.request(request)
    result = JSON.parse(response.body)

    Rails.logger.info "📤 Telegram API response: #{result['ok'] ? '✅ Success' : '❌ Failed'}"
    result
  rescue => e
    Rails.logger.error "❌ Failed to send Telegram message: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    { ok: false, error: e.message }
  end

  def telegram_bot_token
    Rails.application.credentials.dig(:telegram, :bot_token) ||
      ENV["TELEGRAM_BOT_TOKEN"]
  end
end
