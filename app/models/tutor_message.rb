class TutorMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :user
  # A chat belongs to a reading lesson or to a classroom lesson, never both.
  belongs_to :lesson, optional: true
  belongs_to :class_lesson, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true, length: { maximum: 8_000 }
  validates :context, length: { maximum: 16_000 }
  validate :one_home

  scope :chronological, -> { order(:created_at, :id) }
  scope :settled, -> { where(pending: false) }
  scope :questions_today, -> { where(role: "user", created_at: Time.current.beginning_of_day..) }

  # Tutor chats are kept for a limited time (see the privacy page).
  RETENTION = 365.days
  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  # Where the chat happens, and who answers there.
  def home = class_lesson || lesson
  def tutor_name = class_lesson ? class_lesson.professor.presence || "Your professor" : lesson.course.tutor_name

  private
    def one_home
      errors.add(:base, "belongs to one lesson") unless lesson_id.present? ^ class_lesson_id.present?
    end
end
