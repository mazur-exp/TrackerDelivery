class Restaurant < ApplicationRecord
  belongs_to :user
  has_many :notification_contacts, dependent: :destroy
  has_many :working_hours, dependent: :destroy
  has_many :restaurant_status_checks, dependent: :destroy
  has_many :menu_items, dependent: :destroy

  # Enums
  enum :platform, { grab: "grab", gojek: "gojek" }

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :user_id, presence: true
  validates :platform, presence: true, inclusion: { in: platforms.keys }
  validates :platform_url, presence: true
  validate :valid_platform_url

  # Scopes
  scope :grab_restaurants, -> { where(platform: "grab") }
  scope :gojek_restaurants, -> { where(platform: "gojek") }
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :ordered_by_status, -> { order(is_active: :desc, created_at: :desc) }

  # Instance methods
  def display_name
    name.present? ? name : "Restaurant ##{id}"
  end

  def short_name
    name.gsub(/\s*\([^)]*\)\s*/, " ").strip.gsub(/\s+/, " ")
  end

  def platform_name
    platform.humanize
  end

  def is_grab?
    platform == "grab"
  end

  def is_gojek?
    platform == "gojek"
  end

  def active?
    is_active
  end

  def deactivate!
    update!(is_active: false)
  end

  def activate!
    update!(is_active: true)
  end

  def toggle_active!
    update!(is_active: !is_active)
  end

  # Coordinates methods
  def coordinates_hash
    return nil unless coordinates.present?
    JSON.parse(coordinates) rescue nil
  end

  def latitude
    coords = coordinates_hash
    coords&.dig("latitude") || coords&.dig("lat")
  end

  def longitude
    coords = coordinates_hash
    coords&.dig("longitude") || coords&.dig("lng") || coords&.dig("long")
  end

  def set_coordinates(lat, lng)
    self.coordinates = { latitude: lat, longitude: lng }.to_json
  end


  # Notification contact methods
  def all_whatsapp_contacts
    notification_contacts.where(contact_type: "whatsapp").active.ordered.pluck(:contact_value)
  end

  def all_telegram_contacts
    notification_contacts.where(contact_type: "telegram").active.ordered.pluck(:contact_value)
  end

  def all_email_contacts
    notification_contacts.where(contact_type: "email").active.ordered.pluck(:contact_value)
  end

  def has_required_contacts?
    has_whatsapp_contact? || has_telegram_contact?
  end

  def has_whatsapp_contact?
    notification_contacts.where(contact_type: "whatsapp").active.exists?
  end

  def has_telegram_contact?
    notification_contacts.where(contact_type: "telegram").active.exists?
  end

  def has_email_contact?
    notification_contacts.where(contact_type: "email").active.exists?
  end

  # Cuisine methods
  def all_cuisines
    [ cuisine_primary, cuisine_secondary, cuisine_tertiary ].compact.reject(&:blank?)
  end

  def cuisine_display
    all_cuisines.join(", ")
  end

  def set_cuisines(cuisine_array)
    cuisines = cuisine_array.compact.reject(&:blank?).first(3)
    self.cuisine_primary = cuisines[0]
    self.cuisine_secondary = cuisines[1]
    self.cuisine_tertiary = cuisines[2]
  end

  # Working hours methods
  def working_hours_for_day(day)
    working_hours.for_day(day).first
  end

  def is_open_on_day?(day)
    hours = working_hours_for_day(day)
    hours.present? && !hours.is_closed?
  end

  def schedule_summary
    working_hours.includes(:restaurant).map do |wh|
      "#{wh.day_name}: #{wh.full_schedule_text}"
    end.join("; ")
  end

  # Status monitoring methods
  def expected_status_at(time = Time.current)
    # Convert to Indonesia time (most restaurants are in WIB/WITA)
    local_time = time.in_time_zone('Asia/Jakarta')
    day_of_week = (local_time.wday + 6) % 7  # Convert Ruby's wday (0=Sunday) to our format (0=Monday)
    hours = working_hours.for_day(day_of_week).first
    
    return "unknown" unless hours
    return "closed" if hours.is_closed?
    
    current_time = local_time.strftime('%H:%M')
    
    if hours.opens_at.present? && hours.closes_at.present?
      return "open" if current_time >= hours.opens_at.strftime('%H:%M') && current_time <= hours.closes_at.strftime('%H:%M')
      return "closed"
    end
    
    "unknown"
  end

  def latest_status_check
    restaurant_status_checks.order(checked_at: :desc).first
  end

  def has_recent_anomaly?(within = 2.hours)
    restaurant_status_checks.where("checked_at > ? AND is_anomaly = ?", within.ago, true).exists?
  end

  private

  def valid_platform_url
    return unless platform_url.present? && platform.present?

    case platform
    when "grab"
      unless platform_url.match?(/r\.grab\.com|grabfood|grab\.com/i)
        errors.add(:platform_url, "is not a valid Grab URL")
      end
    when "gojek"
      unless platform_url.match?(/gofood\.link|gofood\.co\.id|gojek/i)
        errors.add(:platform_url, "is not a valid GoJek/GoFood URL")
      end
    end
  end
end
