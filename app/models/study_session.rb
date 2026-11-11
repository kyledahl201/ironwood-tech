class StudySession < ApplicationRecord
  belongs_to :user

  validates :studied_on, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 16 * 60 }
  validates :note, length: { maximum: 200 }
  validate :not_in_the_future

  SOURCES = %w[manual auto].freeze
  validates :source, inclusion: { in: SOURCES }

  # What the time was spent on. Automatic records use the first four.
  ACTIVITIES = %w[class homework study lab reading practice other].freeze
  LABELS = { "class" => "Class", "homework" => "Homework", "study" => "Study page", "lab" => "Code lab",
             "reading" => "Reading", "practice" => "Practice on my Mac", "other" => "Other study" }.freeze
  MAX_PULSE = 90 # seconds one report may add
  validates :activity, inclusion: { in: ACTIVITIES }, allow_nil: true

  def auto? = source == "auto"
  def label = LABELS[activity] || note.presence || "Study"

  # Adds measured seconds to an automatic record. One report adds at most
  # MAX_PULSE seconds, and never more than the time since the last report,
  # so the record can't grow faster than the clock.
  def add_seconds(amount)
    amount = amount.clamp(0, MAX_PULSE)
    amount = [ amount, (Time.current - updated_at).ceil + 5 ].min if persisted?
    self.seconds += [ amount, 0 ].max
    self.minutes = [ (seconds / 60.0).round, 1 ].max
    self.updated_at = Time.current # even a report that adds nothing moves the clock on
  end

  scope :manual, -> { where(source: "manual") }
  scope :auto, -> { where(source: "auto") }
  scope :recent, -> { order(studied_on: :desc, created_at: :desc) }

  private
    def not_in_the_future
      errors.add(:studied_on, "can't be in the future") if studied_on && studied_on > Date.current
    end
end
