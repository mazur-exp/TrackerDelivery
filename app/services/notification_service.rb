class NotificationService
  def initialize
    @telegram_bot_token = Rails.application.credentials.telegram_bot_token
    @whatsapp_api_token = Rails.application.credentials.whatsapp_api_token
  end

  def send_restaurant_anomaly_alert(restaurant, status_check)
    message = format_anomaly_message(restaurant, status_check)

    # Send to all notification contacts for this restaurant
    restaurant.notification_contacts.each do |contact|
      case contact.contact_type
      when "telegram"
        send_telegram_message(contact.contact_value, message)
      when "whatsapp"
        send_whatsapp_message(contact.contact_value, message)
      when "email"
        send_email_notification(contact.contact_value, restaurant, status_check)
      end
    end

    Rails.logger.info "Sent anomaly alerts for restaurant #{restaurant.name} to #{restaurant.notification_contacts.count} contacts"
  end

  def send_monitoring_summary(results, duration)
    message = format_summary_message(results, duration)

    # Send summary to admin contacts (you can configure these)
    admin_contacts = get_admin_contacts

    admin_contacts.each do |contact|
      case contact[:type]
      when "telegram"
        send_telegram_message(contact[:value], message)
      when "whatsapp"
        send_whatsapp_message(contact[:value], message)
      end
    end
  end

  private

  def format_anomaly_message(restaurant, status_check)
    severity_emoji = case status_check.severity
    when :critical then "🚨"
    when :warning then "⚠️"
    else "ℹ️"
    end

    current_time = Time.current.in_time_zone("Asia/Makassar").strftime("%H:%M")

    <<~MESSAGE
      #{severity_emoji} *Restaurant Status Alert*

      *Restaurant:* #{restaurant.name}
      *Platform:* #{restaurant.platform.upcase}
      *Time:* #{current_time} WITA

      *Issue:* #{status_check.anomaly_description}

      *Expected:* #{status_check.expected_status.upcase}
      *Actual:* #{status_check.actual_status.upcase}

      Please check your restaurant immediately!

      _TrackerDelivery Monitoring System_
    MESSAGE
  end

  def format_summary_message(results, duration)
    <<~MESSAGE
      📊 *Monitoring Summary*

      *Checked:* #{results[:checked]}/#{results[:total]} restaurants
      *Anomalies:* #{results[:anomalies]}
      *Errors:* #{results[:errors]}
      *Duration:* #{duration.round(1)}s

      #{results[:anomalies] > 0 ? '⚠️ Action required for anomalies!' : '✅ All restaurants operating normally'}

      _TrackerDelivery System_
    MESSAGE
  end

  def send_telegram_message(chat_id, message)
    return unless @telegram_bot_token

    begin
      uri = URI("https://api.telegram.org/bot#{@telegram_bot_token}/sendMessage")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        chat_id: chat_id,
        text: message,
        parse_mode: "Markdown"
      }.to_json

      response = http.request(request)

      if response.code == "200"
        Rails.logger.info "Telegram message sent to #{chat_id}"
      else
        Rails.logger.error "Failed to send Telegram message: #{response.code} #{response.body}"
      end

    rescue => e
      Rails.logger.error "Error sending Telegram message: #{e.message}"
    end
  end

  def send_whatsapp_message(phone_number, message)
    # Note: This is a placeholder for WhatsApp integration
    # You'll need to implement based on your WhatsApp API provider
    # (e.g., Twilio, WhatsApp Business API, etc.)

    Rails.logger.info "WhatsApp message would be sent to #{phone_number}: #{message.truncate(50)}"

    # Example with Twilio (uncomment and configure if needed):
    # begin
    #   client = Twilio::REST::Client.new(account_sid, auth_token)
    #
    #   client.messages.create(
    #     from: 'whatsapp:+14155238886',  # Your Twilio WhatsApp number
    #     to: "whatsapp:#{phone_number}",
    #     body: message
    #   )
    #
    #   Rails.logger.info "WhatsApp message sent to #{phone_number}"
    # rescue => e
    #   Rails.logger.error "Error sending WhatsApp message: #{e.message}"
    # end
  end

  def send_email_notification(email, restaurant, status_check)
    # Use ActionMailer to send email notifications
    begin
      RestaurantAlertMailer.anomaly_alert(email, restaurant, status_check).deliver_now
      Rails.logger.info "Email notification sent to #{email}"
    rescue => e
      Rails.logger.error "Error sending email notification: #{e.message}"
    end
  end

  def get_admin_contacts
    # Configure admin contacts for system-level notifications
    # You can store these in credentials or environment variables
    [
      # { type: 'telegram', value: 'your_telegram_chat_id' },
      # { type: 'whatsapp', value: '+1234567890' }
    ]
  end
end
