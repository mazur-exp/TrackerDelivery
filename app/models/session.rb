class Session < ApplicationRecord
  belongs_to :user

  before_create :set_user_agent_and_ip
  before_create :set_expiration_times
  before_update :extend_expiration_if_active

  # Cleanup old sessions periodically
  scope :expired, -> { where("expires_at < ? OR max_lifetime_expires_at < ?", Time.current, Time.current) }
  scope :old_style_expired, -> { where("updated_at < ? AND expires_at IS NULL", 30.days.ago) }

  # Get session info for display
  def browser_info
    return "Unknown" if user_agent.blank?

    # Simple browser detection
    case user_agent
    when /Chrome/i
      "Chrome"
    when /Firefox/i
      "Firefox"
    when /Safari/i && !/Chrome/i
      "Safari"
    when /Edge/i
      "Edge"
    when /Opera/i
      "Opera"
    else
      "Unknown Browser"
    end
  end

  def location_info
    return "Unknown" if ip_address.blank?

    # For development, just return the IP
    # In production, you might want to add GeoIP lookup
    ip_address == "127.0.0.1" ? "localhost" : ip_address
  end

  # Check if session is still valid
  def expired?
    return true if expires_at && expires_at < Time.current
    return true if max_lifetime_expires_at && max_lifetime_expires_at < Time.current
    false
  end

  # Extend session expiration on activity
  def extend_expiration!
    return if expired?
    return if max_lifetime_expires_at && max_lifetime_expires_at < 1.day.from_now

    update!(expires_at: 30.days.from_now)
  end

  private

  def set_user_agent_and_ip
    self.user_agent ||= "Unknown"
    self.ip_address ||= "Unknown"
  end

  def set_expiration_times
    self.expires_at = 30.days.from_now  # Inactivity timeout
    self.max_lifetime_expires_at = 90.days.from_now  # Maximum session lifetime
  end

  def extend_expiration_if_active
    # Extend expiration if session is being updated (activity detected)
    if expires_at_was && !expired?
      self.expires_at = 30.days.from_now unless max_lifetime_expires_at && max_lifetime_expires_at < 1.day.from_now
    end
  end
end
