# A code-lab exercise written by a professor. Checks run in the student's
# browser; no solutions are ever stored.
class Exercise < ApplicationRecord
  CHECK_TYPES = %w[stdout method_returns method_stdout_empty source_includes source_excludes source_matches].freeze

  has_many :attempts, dependent: :destroy

  validates :slug, :title, :course_code, presence: true
  validates :slug, uniqueness: true
  validate :known_check_types

  scope :ordered, -> { order(:course_code, :lesson_number, :position, :slug) }

  def to_param = slug

  # Open after the lesson is taught: the transcript says enough lessons are done,
  # or the owner opened it to everyone.
  def unlocked_for?(user)
    return true if open_to_all?
    record = user.course_records.find { |r| r.code == course_code }
    return true if record.present? && record.lessons_done >= lesson_number
    ClassLesson.taught?(user, course_code, lesson_number) # finished in the portal classroom
  end

  def passed_by?(user) = attempts.where(user: user, passed: true).exists?

  private
    def known_check_types
      bad = Array(checks).map { |c| c["type"] } - CHECK_TYPES
      errors.add(:checks, "has unknown types: #{bad.join(', ')}") if bad.any?
    end
end
