class WorkingHour < ApplicationRecord
  belongs_to :restaurant

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :restaurant_id, uniqueness: { scope: :day_of_week }

  validate :opening_hours_logic

  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :open, -> { where(is_closed: false) }
  scope :closed, -> { where(is_closed: true) }

  DAYS_OF_WEEK = {
    0 => "Monday",
    1 => "Tuesday",
    2 => "Wednesday",
    3 => "Thursday",
    4 => "Friday",
    5 => "Saturday",
    6 => "Sunday"
  }.freeze

  def day_name
    DAYS_OF_WEEK[day_of_week]
  end

  def has_break?
    break_start.present? && break_end.present?
  end

  def full_schedule_text
    return "Closed" if is_closed?

    main_hours = "#{opens_at&.strftime('%H:%M')} - #{closes_at&.strftime('%H:%M')}"

    if has_break?
      break_hours = "Break: #{break_start.strftime('%H:%M')} - #{break_end.strftime('%H:%M')}"
      "#{main_hours}, #{break_hours}"
    else
      main_hours
    end
  end

  private

  def opening_hours_logic
    return if is_closed?

    if opens_at.blank? || closes_at.blank?
      errors.add(:base, "Opening and closing times are required when not closed")
    end

    if opens_at.present? && closes_at.present? && opens_at >= closes_at
      errors.add(:closes_at, "must be after opening time")
    end

    if has_break?
      if break_start >= break_end
        errors.add(:break_end, "must be after break start")
      end

      if break_start < opens_at || break_end > closes_at
        errors.add(:base, "Break time must be within opening hours")
      end
    end
  end
end
