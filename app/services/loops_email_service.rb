class LoopsEmailService
  include HTTParty
  base_uri 'https://app.loops.so/api/v1'
  
  class << self
    def send_email_confirmation(user, token)
      # Build URL using proper Rails URL options
      host = Rails.application.config.action_mailer.default_url_options[:host] || ENV['RAILS_HOST'] || 'localhost'
      protocol = Rails.application.config.action_mailer.default_url_options[:protocol] || (Rails.env.production? ? 'https' : 'http')
      port = Rails.application.config.action_mailer.default_url_options[:port]
      
      confirmation_url = if port && !Rails.env.production?
        "#{protocol}://#{host}:#{port}/email_confirmation?token=#{token}"
      else
        "#{protocol}://#{host}/email_confirmation?token=#{token}"
      end
      
      Rails.logger.info "Sending email confirmation to #{user.email_address} with URL: #{confirmation_url}"
      
      send_transactional(
        email: user.email_address,
        transactional_id: transactional_id(:email_confirmation),
        data_variables: {
          name: user.display_name,
          confirmationUrl: confirmation_url
        },
        add_to_audience: true
      )
    end
    
    def send_password_reset(user, token)
      # Build URL using proper Rails URL options
      host = Rails.application.config.action_mailer.default_url_options[:host] || ENV['RAILS_HOST'] || 'localhost'
      protocol = Rails.application.config.action_mailer.default_url_options[:protocol] || (Rails.env.production? ? 'https' : 'http')
      port = Rails.application.config.action_mailer.default_url_options[:port]
      
      reset_url = if port && !Rails.env.production?
        "#{protocol}://#{host}:#{port}/reset_password?token=#{token}"
      else
        "#{protocol}://#{host}/reset_password?token=#{token}"
      end
      
      Rails.logger.info "Sending password reset to #{user.email_address} with URL: #{reset_url}"
      
      send_transactional(
        email: user.email_address,
        transactional_id: transactional_id(:password_reset),
        data_variables: {
          name: user.display_name,
          datavariable: reset_url
        }
      )
    end
    
    def send_welcome_email(user)
      # Build URL using proper Rails URL options
      host = Rails.application.config.action_mailer.default_url_options[:host] || ENV['RAILS_HOST'] || 'localhost'
      protocol = Rails.application.config.action_mailer.default_url_options[:protocol] || (Rails.env.production? ? 'https' : 'http')
      port = Rails.application.config.action_mailer.default_url_options[:port]
      
      dashboard_url = if port && !Rails.env.production?
        "#{protocol}://#{host}:#{port}/dashboard"
      else
        "#{protocol}://#{host}/dashboard"
      end
      
      Rails.logger.info "Sending welcome email to #{user.email_address}"
      
      send_transactional(
        email: user.email_address,
        transactional_id: transactional_id(:welcome),
        data_variables: {
          name: user.display_name,
          dashboardUrl: dashboard_url
        },
        add_to_audience: true
      )
    end
    
    private
    
    def send_transactional(email:, transactional_id:, data_variables: {}, add_to_audience: false)
      Rails.logger.info "Preparing Loops API request for #{email}"
      
      # Ensure we have a valid transactional ID
      if transactional_id.blank?
        Rails.logger.error "Missing transactional ID for email: #{email}"
        return false
      end
      
      payload = {
        email: email,
        transactionalId: transactional_id,
        dataVariables: data_variables,
        addToAudience: add_to_audience
      }
      
      Rails.logger.info "Loops API payload: #{payload.inspect}"
      
      response = post(
        '/transactional',
        headers: {
          'Authorization' => "Bearer #{api_key}",
          'Content-Type' => 'application/json'
        },
        body: payload.to_json,
        timeout: 30
      )
      
      Rails.logger.info "Loops API response - Code: #{response.code}"
      Rails.logger.info "Loops API response - Body: #{response.body}" if response.body.present?
      
      if response.success?
        Rails.logger.info "Loops email sent successfully to #{email}"
        true
      else
        Rails.logger.error "Failed to send Loops email to #{email}: #{response.code} - #{response.body}"
        false
      end
    rescue HTTParty::Error => e
      Rails.logger.error "HTTParty error sending Loops email to #{email}: #{e.message}"
      false
    rescue => e
      Rails.logger.error "Unexpected error sending Loops email to #{email}: #{e.message}"
      false
    end
    
    def api_key
      key = Rails.application.credentials.dig(:loops, :api_token) || ENV['LOOPS_API_KEY']
      if key.blank?
        Rails.logger.error "Missing Loops API key in credentials or environment"
      end
      key
    end
    
    def transactional_id(type)
      id = Rails.application.credentials.dig(:loops, :transactional_ids, type) || 
           ENV["LOOPS_#{type.to_s.upcase}_ID"]
      
      # Fallback to hardcoded IDs (from conversation history)
      if type == :email_confirmation && id.blank?
        id = "cmfjb3x522zdky30ielc0fyw0"
        Rails.logger.info "Using hardcoded email confirmation template ID: #{id}"
      end
      
      if type == :password_reset && id.blank?
        id = "cmfjyb0t59hqgx70idh9pi97c"
        Rails.logger.info "Using hardcoded password reset template ID: #{id}"
      end
      
      if id.blank?
        Rails.logger.error "Missing transactional ID for #{type}"
      end
      
      id
    end
  end
end