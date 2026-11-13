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
  has_many :gifts_bought, class_name: "Gift", foreign_key: :purchaser_id, dependent: :nullify, inverse_of: :purchaser
  has_many :gifts_given, class_name: "Gift", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by
  has_many :gifts_claimed, class_name: "Gift", foreign_key: :redeemed_by_id, dependent: :nullify, inverse_of: :redeemed_by

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

  # The one ownership rule. Course content (lessons, the player, classroom
  # classes, exercises, tutors, tutor kits) opens only for the owner of the
  # site, or for a student who owns the course: an enrollment that hasn't been
  # revoked, from a confirmed purchase, an owner grant or a claimed gift.
  def can_open?(course)
    return false unless course
    admin? || enrolled_in?(course)
  end

  # The same rule for classroom content, which carries a course code
  # ("CS 101") instead of a course: the code's Course must be owned.
  def can_open_code?(code)
    admin? || owned_codes.include?(code)
  end

  def owned_codes
    @owned_codes ||= Course.where(id: enrollments.active.select(:course_id)).where.not(code: nil).pluck(:code).to_set
  end

  def reload(*)
    @owned_codes = nil
    super
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
