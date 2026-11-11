# Handed-in homework. "Submitted, awaiting review" until the professor logs a
# grade in the transcript; the portal never grades it.
class HomeworkSubmission < ApplicationRecord
  belongs_to :user
  belongs_to :class_lesson

  validates :work, presence: true, length: { maximum: 20_000 }
  validates :task_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
