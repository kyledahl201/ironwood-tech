# A tutor chat can now happen in the classroom as well as on a reading lesson.
# `context` holds the workbench snapshot the student chose to send with a
# question (their own work and what the checks said), so the tutor can see it.
class AddClassLessonToTutorMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :tutor_messages, :class_lesson, null: true, foreign_key: true
    add_column :tutor_messages, :context, :text
    add_column :tutor_messages, :homework, :boolean, default: false, null: false # asked from the homework page
    change_column_null :tutor_messages, :lesson_id, true
  end
end
