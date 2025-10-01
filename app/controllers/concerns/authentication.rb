module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    resume_session
  end

  def current_user
    Current.user
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    return nil unless cookies.signed[:session_id]

    session = Session.find_by(id: cookies.signed[:session_id])
    return nil unless session

    # Check if session has expired
    if session.expired?
      session.destroy
      cookies.delete(:session_id)
      return nil
    end

    # Extend session expiration on activity
    session.extend_expiration!
    session
  end

  def request_authentication
    if request.format.json? || request.xhr?
      render json: { success: false, errors: ["Authentication required"] }, status: :unauthorized
    else
      session[:return_to_after_authenticating] = request.url
      redirect_to root_path, alert: "Please sign in to continue."
    end
  end

  def start_new_session_for(user)
    user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |new_session|
      Current.session = new_session
      cookies.signed.permanent[:session_id] = {
        value: new_session.id,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
      Rails.logger.info "Started new session #{new_session.id} for user #{user.id}"
    end
  end

  def terminate_session
    if Current.session
      Rails.logger.info "Terminating session #{Current.session.id}"
      Current.session.destroy
      Current.reset
    end
    cookies.delete(:session_id)
  end

  def after_authentication_url
    return session.delete(:return_to_after_authenticating) if session[:return_to_after_authenticating].present?

    # If user has restaurants configured, redirect to dashboard
    # Otherwise, redirect to onboarding
    if current_user.has_restaurants?
      "/dashboard"
    else
      "/onboarding"
    end
  end
end
