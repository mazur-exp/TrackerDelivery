class AuthenticationMailer < ApplicationMailer
  # DISABLED - We use Loops.so API for email sending
  # This mailer interfered with our custom EmailService
  
  def email_confirmation(user)
    # Disabled - handled by EmailService/LoopsService
    Rails.logger.info "AuthenticationMailer disabled - email handled by Loops API"
    return
  end

  def welcome_email(user)
    @user = user
    
    mail(
      to: @user.email_address,
      subject: "Welcome to TrackerDelivery!"
    )
  end
end