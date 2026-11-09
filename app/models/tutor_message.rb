class TutorMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :user
  belongs_to :lesson

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true, length: { maximum: 8_000 }

  scope :chronological, -> { order(:created_at, :id) }
  scope :settled, -> { where(pending: false) }
  scope :questions_today, -> { where(role: "user", created_at: Time.current.beginning_of_day..) }

  # Tutor chats are kept for a limited time (see the privacy page).
  RETENTION = 365.days
  scope :expired, -> { where(created_at: ...RETENTION.ago) }
end
