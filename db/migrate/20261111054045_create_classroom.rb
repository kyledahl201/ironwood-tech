class CreateClassroom < ActiveRecord::Migration[8.1]
  def change
    # A scripted lesson the classroom plays step by step (written by the faculty).
    create_table :class_lessons do |t|
      t.string :slug, null: false
      t.string :course_code, null: false
      t.integer :lesson_number, null: false
      t.string :title, null: false
      t.string :professor
      t.integer :minutes
      t.json :steps, null: false, default: []
      t.json :study_guide, null: false, default: []
      t.json :flashcards, null: false, default: []
      t.json :homework, null: false, default: []
      t.timestamps
    end
    add_index :class_lessons, :slug, unique: true
    add_index :class_lessons, [ :course_code, :lesson_number ]

    # Where a student is in a lesson, and in its homework.
    create_table :class_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :class_lesson, null: false, foreign_key: true
      t.integer :step_index, null: false, default: 0
      t.datetime :completed_at
      t.json :quiz_first, null: false, default: {} # step number => was the first answer right
      t.integer :hints_used, null: false, default: 0
      t.timestamps
    end
    add_index :class_progresses, [ :user_id, :class_lesson_id ], unique: true

    # Homework the student handed in. The professor grades it; the portal only
    # records that it passed its checks and was submitted.
    create_table :homework_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :class_lesson, null: false, foreign_key: true
      t.integer :task_index, null: false
      t.text :work, null: false
      t.datetime :submitted_at, null: false
      t.timestamps
    end
    add_index :homework_submissions, [ :user_id, :class_lesson_id, :task_index ], unique: true, name: "index_homework_on_user_lesson_task"

    # Time the portal measured by itself (source "auto") next to hand-logged time.
    add_column :study_sessions, :source, :string, null: false, default: "manual"
    add_column :study_sessions, :seconds, :integer, null: false, default: 0
    add_column :study_sessions, :activity, :string
  end
end
