
class User < ApplicationRecord
  has_secure_password validations: false  # Disable default validations, we'll handle them manually
  has_many :sessions, dependent: :destroy
  has_many :restaurants, dependent: :destroy

  # Validations
  # Email is optional for Telegram users
  validates :email_address,
            uniqueness: { case_sensitive: false, allow_nil: true },
            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # At least one authentication method must be present
  validate :authentication_method_present

  # Password validation only for email users
  validates :password, length: { minimum: 8 }, if: :password_required?

  # Telegram ID must be unique if present
  validates :telegram_id, uniqueness: true, allow_nil: true

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
    return name if name.present?
    return telegram_first_name if telegram_first_name.present?
    return telegram_username if telegram_username.present?
    return email_address.split("@").first.capitalize if email_address.present?
    "User ##{id}"
  end

  # Check if user authenticated via Telegram
  def telegram_user?
    telegram_id.present?
  end

  # Check if user authenticated via Email
  def email_user?
    email_address.present? && password_digest.present?
  end

  # Check if user authenticated via Google
  def google_user?
    google_id.present?
  end

  # Check if user authenticated via Apple
  def apple_user?
    apple_id.present?
  end

  # Check if user authenticated via Facebook
  def facebook_user?
    facebook_id.present?
  end

  # Check if user has multiple authentication methods linked
  def has_multiple_auth_methods?
    auth_methods_count > 1
  end

  # Count how many auth methods user has
  def auth_methods_count
    [
      telegram_id,
      google_id,
      apple_id,
      facebook_id,
      (email_address.present? && password_digest.present? ? true : nil)
    ].compact.count
  end

  # Get primary authentication method (first one registered)
  def primary_auth_method
    return :telegram if telegram_id.present?
    return :google if google_id.present?
    return :email if email_address.present? && password_digest.present?
    return :apple if apple_id.present?
    return :facebook if facebook_id.present?
    :none
  end

  # List all connected auth methods
  def connected_auth_methods
    methods = []
    methods << :telegram if telegram_user?
    methods << :email if email_user?
    methods << :google if google_user?
    methods << :apple if apple_user?
    methods << :facebook if facebook_user?
    methods
  end

  # Check if user has any restaurants configured
  def has_restaurants?
    restaurants.exists?
  end

  # Get all unique notification contacts from user's restaurants
  def all_whatsapp_contacts
    restaurants.joins(:notification_contacts)
               .where(notification_contacts: { contact_type: "whatsapp", is_active: true })
               .pluck("notification_contacts.contact_value")
               .uniq
  end

  def all_telegram_contacts
    restaurants.joins(:notification_contacts)
               .where(notification_contacts: { contact_type: "telegram", is_active: true })
               .pluck("notification_contacts.contact_value")
               .uniq
  end

  def all_email_contacts
    restaurants.joins(:notification_contacts)
               .where(notification_contacts: { contact_type: "email", is_active: true })
               .pluck("notification_contacts.contact_value")
               .uniq
  end

  private

  def authentication_method_present
    # Check if user has at least one authentication method
    has_any_auth = telegram_id.present? ||
                   google_id.present? ||
                   apple_id.present? ||
                   facebook_id.present? ||
                   (email_address.present? && password_digest.present?)

    unless has_any_auth
      errors.add(:base, "Must have at least one authentication method (Telegram, Google, Email, Apple, or Facebook)")
    end
  end

  def password_required?
    # Password required only for email users (not for Telegram users)
    email_user? && (new_record? || password.present?)
  end

  def email_just_confirmed?
    saved_change_to_email_confirmed_at? && email_confirmed_at.present?
  end

  def send_email_confirmation
    # Skip email confirmation for Telegram users
    return if telegram_user?

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
    # Skip validation for Telegram users or if email is blank
    return if email_address.blank? || telegram_user?

    if EmailDomainBlacklist.blacklisted?(email_address)
      domain = EmailDomainBlacklist.extract_domain(email_address)
      errors.add(:email_address, "This email domain (#{domain}) is not supported.")
    end
  end
end
