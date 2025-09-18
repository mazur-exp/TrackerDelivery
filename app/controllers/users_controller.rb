class UsersController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      Rails.logger.info "User created successfully: #{@user.email_address}"

      # For development - show confirmation link in console
      if Rails.env.development? && @user.email_confirmation_token.present?
        Rails.logger.info "🔧 Development Mode: Confirmation link: http://localhost:3001/email_confirmation?token=#{@user.email_confirmation_token}"
      end

      redirect_to new_session_path, notice: "Account created successfully! Please check your email to confirm your account."
    else
      Rails.logger.warn "User creation failed: #{@user.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :name)
  end
end
