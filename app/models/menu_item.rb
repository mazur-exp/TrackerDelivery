class MenuItem < ApplicationRecord
  belongs_to :restaurant

  scope :out_of_stock, -> { where(current_status: 0) }
  scope :available, -> { where(current_status: 1) }

  def out_of_stock?
    current_status == 0
  end

  def out_of_stock_duration
    return nil unless out_of_stock? && status_changed_at
    Time.current - status_changed_at
  end
end
