class CuisineTranslation < ApplicationRecord
  validates :indonesian, presence: true, uniqueness: true
  validates :english, presence: true

  # Normalize indonesian text before saving
  before_validation :normalize_indonesian

  private

  def normalize_indonesian
    self.indonesian = indonesian&.downcase&.strip
  end
end
