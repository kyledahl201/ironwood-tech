class LessonCompletion < ApplicationRecord
  belongs_to :enrollment
  belongs_to :lesson

  validates :lesson_id, uniqueness: { scope: :enrollment_id }
end
