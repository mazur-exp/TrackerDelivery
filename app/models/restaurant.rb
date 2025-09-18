class Restaurant < ApplicationRecord
  belongs_to :user
  has_many :notification_contacts, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :user_id, presence: true
  validate :at_least_one_platform_url
  validate :valid_platform_urls
  
  # Scopes
  scope :with_grab, -> { where.not(grab_url: [nil, '']) }
  scope :with_gojek, -> { where.not(gojek_url: [nil, '']) }
  
  # Instance methods
  def display_name
    name.present? ? name : "Restaurant ##{id}"
  end
  
  def has_grab_url?
    grab_url.present?
  end
  
  def has_gojek_url?
    gojek_url.present?
  end
  
  def platform_count
    count = 0
    count += 1 if has_grab_url?
    count += 1 if has_gojek_url?
    count
  end
  
  def extract_name_from_urls
    # Try to extract restaurant name from URLs if name is not provided
    return name if name.present?
    
    # This would be implemented with actual URL parsing logic
    # For now, return a placeholder
    "Restaurant from URLs"
  end
  
  # Notification contact methods
  def all_whatsapp_contacts
    notification_contacts.where(contact_type: 'whatsapp').active.ordered.pluck(:contact_value)
  end

  def all_telegram_contacts
    notification_contacts.where(contact_type: 'telegram').active.ordered.pluck(:contact_value)
  end

  def all_email_contacts
    notification_contacts.where(contact_type: 'email').active.ordered.pluck(:contact_value)
  end

  def has_required_contacts?
    has_whatsapp_contact? || has_telegram_contact?
  end

  def has_whatsapp_contact?
    notification_contacts.where(contact_type: 'whatsapp').active.exists?
  end

  def has_telegram_contact?
    notification_contacts.where(contact_type: 'telegram').active.exists?
  end

  def has_email_contact?
    notification_contacts.where(contact_type: 'email').active.exists?
  end
  
  private
  
  def at_least_one_platform_url
    unless grab_url.present? || gojek_url.present?
      errors.add(:base, "At least one platform URL (Grab or GoJek) is required")
    end
  end
  
  def valid_platform_urls
    if grab_url.present? && !valid_grab_url?
      errors.add(:grab_url, "is not a valid Grab URL")
    end
    
    if gojek_url.present? && !valid_gojek_url?
      errors.add(:gojek_url, "is not a valid GoJek/GoFood URL")
    end
  end
  
  def valid_grab_url?
    return false unless grab_url.present?
    grab_url.match?(/r\.grab\.com|grabfood|grab\.com/i)
  end
  
  def valid_gojek_url?
    return false unless gojek_url.present?
    gojek_url.match?(/gofood\.link|gofood\.co\.id|gojek/i)
  end
end
