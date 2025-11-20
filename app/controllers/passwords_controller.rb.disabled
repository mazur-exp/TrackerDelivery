class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: [ :edit, :update ]

  def new
    # Form to request password reset
  end

  def create
    user = User.find_by(email_address: params[:email_address])

    if user
      if user.send_password_reset!
        Rails.logger.info "Password reset requested for user #{user.id}"
        redirect_to login_path, notice: "Password reset instructions have been sent to your email."
      else
        Rails.logger.error "Failed to send password reset for user #{user.id}"
        redirect_to forgot_password_path, alert: "There was an error sending the email. Please try again."
      end
    else
      Rails.logger.warn "Password reset requested for non-existent user: #{params[:email_address]}"
      # Show specific message for non-existent email to help user
      redirect_to forgot_password_path, alert: "No account found with this email address."
    end
  end

  def edit
    # Form to set new password
  end

  def update
    if @user.update(password_params)
      @user.update!(password_reset_token: nil, password_reset_sent_at: nil)

      # Terminate all existing sessions for security
      terminated_count = @user.terminate_other_sessions!
      Rails.logger.info "Password reset successfully for user #{@user.id}, terminated #{terminated_count} sessions"

      redirect_to login_path, notice: "Password has been reset successfully. Please sign in with your new password."
    else
      Rails.logger.warn "Password reset failed for user #{@user.id}: #{@user.errors.full_messages.join(', ')}"
      flash.now[:alert] = @user.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])

    unless @user
      Rails.logger.warn "Invalid or expired password reset token: #{params[:token]}"
      redirect_to forgot_password_path, alert: "Password reset link is invalid or has expired. Please request a new one."
    end
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
