class ClassProgress < ApplicationRecord
  belongs_to :user
  belongs_to :class_lesson

  def completed? = completed_at.present?

  def quiz_total = quiz_first.size
  def quiz_right = quiz_first.values.count(true)

  def percent
    total = class_lesson.steps.size
    return 100 if completed?
    total.zero? ? 0 : (step_index * 100 / total).clamp(0, 99)
  end
end
