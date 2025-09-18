class NotificationContact < ApplicationRecord
  belongs_to :user
  
  # Constants
  CONTACT_TYPES = %w[whatsapp telegram email].freeze
  MAX_CONTACTS_PER_TYPE = 5
  
  # Validations
  validates :contact_type, presence: true, inclusion: { in: CONTACT_TYPES }
  validates :contact_value, presence: true
  validates :user_id, presence: true
  validate :valid_contact_format
  validate :max_contacts_per_type_limit
  
  # Callbacks
  before_create :set_priority_order
  before_create :set_primary_if_first
  after_create :ensure_only_one_primary_per_type
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(contact_type: type) }
  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_primary: false) }
  scope :ordered, -> { order(:priority_order) }
  
  # Class methods
  def self.create_contacts_from_string(user, contact_type, contact_string)
    return [] if contact_string.blank?
    
    contacts = parse_contact_string(contact_string)
    created_contacts = []
    
    contacts.each_with_index do |contact_value, index|
      next if contact_value.blank?
      
      contact = user.notification_contacts.build(
        contact_type: contact_type,
        contact_value: normalize_contact_value(contact_value, contact_type)
      )
      
      if contact.save
        created_contacts << contact
      end
    end
    
    created_contacts
  end
  
  def self.parse_contact_string(contact_string)
    return [] if contact_string.blank?
    
    contact_string.split(',').map(&:strip).reject(&:blank?)
  end
  
  def self.normalize_contact_value(value, contact_type)
    case contact_type
    when 'whatsapp'
      # Remove spaces and ensure + prefix
      normalized = value.gsub(/\s+/, '')
      normalized.start_with?('+') ? normalized : "+#{normalized}"
    when 'telegram'
      # Ensure @ prefix for username
      value.start_with?('@') ? value : "@#{value}"
    when 'email'
      value.downcase.strip
    else
      value.strip
    end
  end
  
  # Instance methods
  def display_value
    case contact_type
    when 'whatsapp'
      # Format phone number with spaces for display: +62 812 3456 7890
      contact_value.gsub(/(\+\d{2})(\d{3})(\d{4})(\d{4})/, '\1 \2 \3 \4')
    else
      contact_value
    end
  end
  
  def formatted_type
    contact_type.capitalize
  end
  
  def primary?
    is_primary?
  end
  
  def secondary?
    !is_primary?
  end
  
  private
  
  def valid_contact_format
    case contact_type
    when 'whatsapp'
      validate_whatsapp_format
    when 'telegram'
      validate_telegram_format
    when 'email'
      validate_email_format
    end
  end
  
  def validate_whatsapp_format
    # Accepts formats: +6281234567890, 6281234567890, 081234567890
    phone_regex = /\A(\+?\d{10,15})\z/
    unless contact_value&.gsub(/\s+/, '')&.match?(phone_regex)
      errors.add(:contact_value, "is not a valid phone number format")
    end
  end
  
  def validate_telegram_format
    # Accepts @username or username
    telegram_regex = /\A@?[a-zA-Z0-9_]{5,32}\z/
    unless contact_value&.match?(telegram_regex)
      errors.add(:contact_value, "is not a valid Telegram username")
    end
  end
  
  def validate_email_format
    unless contact_value&.match?(URI::MailTo::EMAIL_REGEXP)
      errors.add(:contact_value, "is not a valid email address")
    end
  end
  
  def max_contacts_per_type_limit
    existing_count = user.notification_contacts
                        .where(contact_type: contact_type)
                        .where.not(id: id)
                        .count
                        
    if existing_count >= MAX_CONTACTS_PER_TYPE
      errors.add(:base, "Maximum #{MAX_CONTACTS_PER_TYPE} #{contact_type} contacts allowed")
    end
  end
  
  def set_priority_order
    last_priority = user.notification_contacts
                       .where(contact_type: contact_type)
                       .maximum(:priority_order) || 0
    self.priority_order = last_priority + 1
  end
  
  def set_primary_if_first
    if user.notification_contacts.where(contact_type: contact_type).empty?
      self.is_primary = true
    end
  end
  
  def ensure_only_one_primary_per_type
    if is_primary?
      # Ensure no other contact of same type is primary
      user.notification_contacts
          .where(contact_type: contact_type)
          .where.not(id: id)
          .update_all(is_primary: false)
    end
  end
end