class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :study_sessions, dependent: :destroy
  has_many :course_records, -> { ordered }, dependent: :destroy
  has_one :transcript_snapshot, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :user_badges, dependent: :destroy
  has_many :class_progresses, dependent: :destroy
  has_many :study_records, dependent: :destroy
  has_many :homework_submissions, dependent: :destroy
  has_many :courses, through: :enrollments
  has_many :tutor_messages, dependent: :destroy

  enum :role, { student: 0, admin: 1 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 10 }, allow_nil: true

  # Revoked (refunded) enrollments don't count.
  def enrolled_in?(course)
    enrollments.active.exists?(course: course)
  end

  # Who may open a course's lessons or player: the owner, or a student with an
  # enrollment that hasn't been revoked.
  def can_open?(course)
    admin? || enrolled_in?(course)
  end

  # Accounts made by buying a course see the store, what they bought and their
  # account. Invited students and the owner see the whole portal.
  def portal_member? = admin? || !customer_only?

  scope :in_study_hall, -> { where(share_in_study_hall: true) }

  # Reserved for an owner "preview every lesson" switch; off for everyone today.
  def admin_preview? = false

  def first_name
    name.to_s.split.first
  end
end
