class StudySession < ApplicationRecord
  belongs_to :user

  validates :studied_on, presence: true
  validates :minutes, numericality: { only_integer: true, less_than_or_equal_to: 16 * 60 }
  # An automatic record may hold less than a minute so far. Nothing else may.
  validates :minutes, numericality: { greater_than: 0 }, unless: :auto?
  validates :minutes, numericality: { greater_than_or_equal_to: 0 }, if: :auto?
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

  # Adds seconds the portal measured to today's automatic record for a course
  # and activity. Three rules keep it honest:
  # - one report adds at most MAX_PULSE seconds;
  # - a student's reports together never add more than the time on the wall
  #   clock since their last report, so two open windows can't log a minute
  #   twice;
  # - minutes come from whole seconds, rounded down once across the day, so
  #   a few seconds here and there never turn into a minute.
  # Returns the record, or nil when there was nothing to add.
  def self.log_pulse(user, seconds:, course_code:, activity:, now: Time.current)
    user.with_lock do
      allowed = user.last_pulse_at ? (now - user.last_pulse_at).floor : MAX_PULSE
      amount = [ seconds.to_i, allowed, MAX_PULSE ].min
      next nil if amount <= 0
      today = user.study_sessions.auto.where(studied_on: now.in_time_zone.to_date)
      record = today.find_or_initialize_by(course_code: course_code, activity: activity)
      record.seconds += amount
      others = today.where.not(id: record.id)
      record.minutes = [ (others.sum(:seconds) + record.seconds) / 60 - others.sum(:minutes), 0 ].max # never below 0 if a row was removed
      record.save!
      user.update!(last_pulse_at: now)
      record
    end
  end

  scope :manual, -> { where(source: "manual") }
  scope :auto, -> { where(source: "auto") }
  scope :logged, -> { where("minutes > 0") } # leaves out automatic records still under a minute
  scope :recent, -> { order(studied_on: :desc, created_at: :desc) }

  private
    def not_in_the_future
      errors.add(:studied_on, "can't be in the future") if studied_on && studied_on > Date.current
    end
end
