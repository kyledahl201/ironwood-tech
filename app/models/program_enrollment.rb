# Owning a program: bought (Stripe confirmed the payment), given by the owner,
# or a claimed gift. It gives its owner an enrollment in every course in the
# program (fan_out!), so the one ownership rule (User#can_open?) opens every
# class. Ending it (a refund, a dispute, the owner) ends the enrollments it
# gave; a course the student owns on its own stays theirs.
class ProgramEnrollment < ApplicationRecord
  SOURCES = Enrollment::SOURCES

  belongs_to :user
  belongs_to :program
  belongs_to :gift, optional: true
  has_many :enrollments, dependent: :nullify

  validates :source, inclusion: { in: SOURCES }
  validates :program_id, uniqueness: { scope: :user_id }

  scope :active, -> { where(revoked_at: nil) }

  def active? = revoked_at.nil?
  def paid? = source == "purchase"

  # Gives user the program, or gives it back when it had ended. A payment
  # recorded on an active program (it was given, then bought) is kept on it.
  # Returns the program enrollment.
  def self.grant!(user:, program:, **attrs)
    transaction do
      pe = find_or_initialize_by(user: user, program: program)
      if pe.new_record?
        pe.update!(attrs)
      elsif !pe.active?
        pe.update!(attrs.merge(revoked_at: nil, revoke_reason: nil))
      elsif attrs[:source] == "purchase" && !pe.paid?
        pe.update!(attrs)
      end
      pe.fan_out!(reinstate: true)
      pe
    end
  end

  # An enrollment in each course of the program, for an active program
  # enrollment. Courses the student already owns are left as they are.
  # reinstate: also give back a course whose access had ended (on a grant;
  # Program.sync! only adds missing ones, so an owner's single revoke sticks).
  def fan_out!(reinstate: false)
    return unless active?
    program.courses.each do |course|
      enrollment = user.enrollments.find_or_initialize_by(course: course)
      if enrollment.new_record?
        enrollment.update!(source: source, program_enrollment: self)
      elsif !enrollment.active? && reinstate
        enrollment.reinstate!(source: source, program_enrollment: self, gift: nil)
      end
    end
  end

  # Refunds, disputes and the owner end the program, and the class access it
  # gave. The records stay for the books.
  def revoke!(reason)
    transaction do
      update!(revoked_at: Time.current, revoke_reason: reason) if active?
      enrollments.active.find_each { |e| e.revoke!(reason) }
    end
  end

  def reinstate!
    update!(revoked_at: nil, revoke_reason: nil)
    fan_out!(reinstate: true)
  end
end
