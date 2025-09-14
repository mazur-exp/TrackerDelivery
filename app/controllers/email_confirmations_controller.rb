class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: [:show]
  
  def show
    if @user.email_confirmed?
      Rails.logger.info "User #{@user.id} attempted to confirm already confirmed email"
      redirect_to login_path, notice: "Your email is already confirmed. Please sign in."
      return
    end
    
    @user.confirm_email!
    start_new_session_for(@user)
    Rails.logger.info "User #{@user.id} confirmed email and signed in automatically"
    redirect_to after_authentication_url, notice: "🎉 Email confirmed successfully! Welcome to TrackerDelivery!"
  end
  
  def new
    # Form to resend confirmation email
  end
  
  def create
    user = User.find_by(email_address: params[:email_address])
    
    if user.nil?
      Rails.logger.warn "Attempted to resend confirmation for non-existent user: #{params[:email_address]}"
      redirect_to resend_confirmation_path, alert: "No account found with this email address."
      return
    end
    
    if user.email_confirmed?
      Rails.logger.info "Attempted to resend confirmation for already confirmed user: #{user.id}"
      redirect_to login_path, notice: "Your email is already confirmed. You can sign in now."
      return
    end
    
    # User exists and is not confirmed, try to send confirmation
    if user.send_email_confirmation!
      Rails.logger.info "Resent confirmation email to user #{user.id}"
      redirect_to login_path, notice: "Confirmation email sent! Please check your inbox."
    else
      Rails.logger.error "Failed to resend confirmation email to user #{user.id}"
      redirect_to resend_confirmation_path, alert: "There was an error sending the email. Please try again."
    end
  end
  
  private
  
  def set_user_by_token
    @user = User.find_by_token_for(:email_confirmation, params[:token])
    
    unless @user
      Rails.logger.warn "Invalid or expired email confirmation token: #{params[:token]}"
      redirect_to login_path, alert: "Email confirmation link is invalid or has expired. Please request a new one."
    end
  end
end