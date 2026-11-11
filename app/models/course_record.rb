# One row of the transcript's Courses table (lessons happen with the professors in chat).
class CourseRecord < ApplicationRecord
  belongs_to :user

  validates :code, :title, presence: true

  scope :ordered, -> { order(:position) }

  def in_progress? = status.to_s.downcase.start_with?("in progress")
  def finished? = status.to_s.downcase.match?(/\A(passed|complete)/)

  def hours_percent
    return 0 unless hours_target.to_i.positive?
    [ (hours_logged.to_f * 100 / hours_target).round, 100 ].min
  end
end
