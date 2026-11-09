class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :active_enrollments, -> { active }, class_name: "Enrollment"
  has_many :courses, through: :enrollments
  has_many :tutor_messages, dependent: :destroy

  enum :role, { student: 0, admin: 1 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 10 }, allow_nil: true

  def enrolled_in?(course)
    active_enrollments.exists?(course: course)
  end

  def first_name
    name.to_s.split.first
  end
end
