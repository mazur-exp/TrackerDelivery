class ApplicationController < ActionController::Base
  include Authentication

  before_action :set_locale

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
    Rails.logger.info "🌍 Locale set to: #{I18n.locale}"
  end

  def extract_locale
    # Priority 1: URL parameter (?locale=ru)
    return params[:locale] if params[:locale].in?(I18n.available_locales.map(&:to_s))

    # Priority 2: Session (user manually switched)
    return session[:locale] if session[:locale].in?(I18n.available_locales.map(&:to_s))

    # Priority 3: User preference (if logged in)
    return current_user.locale if authenticated? && current_user.locale.present?

    # Priority 4: Browser Accept-Language header
    detect_locale_from_header
  end

  def detect_locale_from_header
    return nil unless request.env['HTTP_ACCEPT_LANGUAGE']

    # Parse Accept-Language header
    accepted_languages = request.env['HTTP_ACCEPT_LANGUAGE']
                                .split(',')
                                .map { |lang| lang.split(';').first.split('-').first }

    # Find first matching locale
    accepted_languages.find { |lang| lang.in?(I18n.available_locales.map(&:to_s)) }
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
