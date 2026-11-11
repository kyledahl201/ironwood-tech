class StudySession < ApplicationRecord
  belongs_to :user

  validates :studied_on, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 16 * 60 }
  validates :note, length: { maximum: 200 }
  validate :not_in_the_future

  scope :recent, -> { order(studied_on: :desc, created_at: :desc) }

  private
    def not_in_the_future
      errors.add(:studied_on, "can't be in the future") if studied_on && studied_on > Date.current
    end
end
