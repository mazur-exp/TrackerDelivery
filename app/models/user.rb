class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :restaurants, dependent: :destroy

  # Validations
  validates :email_address, presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: :password_required?

  # Normalization
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Token generation
  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 24.hours do
    email_address
  end

  # Callbacks
  after_create :send_email_confirmation
  after_update :send_welcome_email, if: :email_just_confirmed?

  # Custom validations
  validate :email_domain_not_blacklisted

  # Email confirmation methods
  def email_confirmed?
    email_confirmed_at.present?
  end

  def confirm_email!
    update!(
      email_confirmed_at: Time.current,
      email_confirmation_token: nil,
      email_confirmation_sent_at: nil
    )
  end

  def send_email_confirmation!
    token = generate_token_for(:email_confirmation)
    update!(
      email_confirmation_token: token,
      email_confirmation_sent_at: Time.current
    )
    LoopsEmailService.send_email_confirmation(self, token)
  rescue => e
    Rails.logger.error "Failed to send email confirmation for user #{id}: #{e.message}"
    false
  end

  def send_password_reset!
    token = generate_token_for(:password_reset)
    update!(
      password_reset_token: token,
      password_reset_sent_at: Time.current
    )
    LoopsEmailService.send_password_reset(self, token)
  rescue => e
    Rails.logger.error "Failed to send password reset for user #{id}: #{e.message}"
    false
  end

  # Display name helper
  def display_name
    name.present? ? name : email_address.split("@").first.capitalize
  end

  # Check if user has any restaurants configured
  def has_restaurants?
    restaurants.exists?
  end

  # Terminate all sessions except the current one
  def terminate_other_sessions!(current_session = nil)
    sessions_to_destroy = current_session ? sessions.where.not(id: current_session.id) : sessions
    destroyed_count = sessions_to_destroy.count
    sessions_to_destroy.destroy_all
    Rails.logger.info "Terminated #{destroyed_count} sessions for user #{id}"
    destroyed_count
  end

  private

  def password_required?
    new_record? || password.present?
  end

  def email_just_confirmed?
    saved_change_to_email_confirmed_at? && email_confirmed_at.present?
  end

  def send_email_confirmation
    send_email_confirmation!
  rescue => e
    Rails.logger.error "Failed to send email confirmation for user #{id}: #{e.message}"
    Rails.logger.info "🔧 Development Mode: You can confirm your account by visiting: http://localhost:3001/email_confirmation?token=#{email_confirmation_token}"
    # Don't fail user creation if email fails - this is good for development
  end

  def send_welcome_email
    LoopsEmailService.send_welcome_email(self)
  rescue => e
    Rails.logger.error "Failed to send welcome email for user #{id}: #{e.message}"
    # Don't fail the confirmation process if welcome email fails
  end

  def email_domain_not_blacklisted
    return if email_address.blank?

    if EmailDomainBlacklist.blacklisted?(email_address)
      domain = EmailDomainBlacklist.extract_domain(email_address)
      errors.add(:email_address, "This email domain (#{domain}) is not supported.")
    end
  end
end
