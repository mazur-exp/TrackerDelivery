class Session < ApplicationRecord
  belongs_to :user
  
  before_create :set_user_agent_and_ip
  
  # Cleanup old sessions periodically
  scope :expired, -> { where('updated_at < ?', 30.days.ago) }
  
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
  
  private
  
  def set_user_agent_and_ip
    self.user_agent ||= 'Unknown'
    self.ip_address ||= 'Unknown'
  end
end