class RestaurantStatusCheck < ApplicationRecord
  belongs_to :restaurant

  validates :restaurant_id, presence: true
  validates :checked_at, presence: true
  validates :actual_status, presence: true
  validates :expected_status, presence: true

  scope :anomalies, -> { where(is_anomaly: true) }
  scope :recent, ->(within = 24.hours) { where("checked_at > ?", within.ago) }
  scope :recent_anomalies, ->(within = 24.hours) { recent(within).anomalies }

  def status_match?
    actual_status == expected_status
  end

  def parsed_response
    JSON.parse(parser_response) if parser_response.present?
  rescue JSON::ParserError
    {}
  end

  def anomaly_severity
    return :none unless is_anomaly?

    case [expected_status, actual_status]
    when ["open", "closed"]
      :high  # Should be open but closed - revenue loss
    when ["closed", "open"] 
      :medium  # Open when should be closed - less critical
    else
      :low
    end
  end

  def time_since_check
    return 0 if checked_at.nil?
    
    ((Time.current - checked_at) / 1.minute).round
  end
end