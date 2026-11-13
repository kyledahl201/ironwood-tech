class Enrollment < ApplicationRecord
  SOURCES = %w[self admin stripe].freeze

  belongs_to :user
  belongs_to :course
  has_many :lesson_completions, dependent: :destroy

  validates :source, inclusion: { in: SOURCES }
  validates :course_id, uniqueness: { scope: :user_id }

  scope :active, -> { where(revoked_at: nil) }

  def active? = revoked_at.nil?
  def paid? = source == "stripe"

  # Refunds, disputes and the owner end access; the record stays for the books.
  def revoke!(reason)
    update!(revoked_at: Time.current, revoke_reason: reason) if active?
  end

  def reinstate!(**attrs)
    update!(attrs.merge(revoked_at: nil, revoke_reason: nil))
  end

  def completed?(lesson)
    lesson_completions.any? { |c| c.lesson_id == lesson.id }
  end

  def progress_percent
    total = course.lessons.size
    return 0 if total.zero?
    (lesson_completions.size * 100.0 / total).round
  end

  def next_lesson
    done = lesson_completions.map(&:lesson_id)
    course.lessons.find { |l| !done.include?(l.id) }
  end

  def finished?
    course.lessons.any? && lesson_completions.size >= course.lessons.size
  end

  def finished_at
    lesson_completions.map(&:created_at).max if finished?
  end

  # Short, stable reference printed on the certificate.
  def certificate_code
    "IT-#{created_at.strftime('%Y')}-#{id.to_s.rjust(5, '0')}"
  end
end
