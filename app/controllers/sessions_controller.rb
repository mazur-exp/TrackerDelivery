class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  # Simple rate limiting - in production, use Redis or similar
  before_action :check_rate_limit, only: :create

  def new
  end

  def create
    # First check if user exists by email
    user = User.find_by(email_address: params[:email_address])

    if user.nil?
      Rails.logger.warn "Login attempt with non-existent email: #{params[:email_address]}"
      record_failed_attempt
      redirect_to login_path, alert: "No account found with this email address."
      return
    end

    # If user exists, check password
    authenticated_user = User.authenticate_by(
      email_address: params[:email_address],
      password: params[:password]
    )

    if authenticated_user
      if authenticated_user.email_confirmed?
        start_new_session_for(authenticated_user)
        Rails.logger.info "User #{authenticated_user.id} signed in successfully"
        redirect_to after_authentication_url, notice: "Welcome back, #{authenticated_user.display_name}!"
      else
        Rails.logger.warn "User #{authenticated_user.id} attempted login without email confirmation"
        redirect_to login_path, alert: "Please confirm your email address. Check your inbox for the confirmation link."
      end
    else
      Rails.logger.warn "Wrong password for user: #{params[:email_address]}"
      record_failed_attempt
      redirect_to login_path, alert: "Incorrect password."
    end
  end

  def destroy
    Rails.logger.info "User signed out: #{current_user&.id}"
    terminate_session
    redirect_to root_path, notice: "You have been signed out successfully."
  end

  private

  def check_rate_limit
    key = "login_attempts:#{request.remote_ip}"
    attempts = Rails.cache.read(key) || 0

    if attempts >= 10
      Rails.logger.warn "Rate limit exceeded for IP: #{request.remote_ip}"
      redirect_to login_path, alert: "Too many login attempts. Please try again in a few minutes."
    end
  end

  def record_failed_attempt
    key = "login_attempts:#{request.remote_ip}"
    attempts = Rails.cache.read(key) || 0
    Rails.cache.write(key, attempts + 1, expires_in: 3.minutes)
  end
end
