# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_054045) do
  create_table "attempts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "exercise_id", null: false
    t.text "code", null: false
    t.boolean "passed", default: false, null: false
    t.integer "checks_passed", default: 0, null: false
    t.integer "hints_used", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_attempts_on_exercise_id"
    t.index ["user_id", "exercise_id", "passed"], name: "index_attempts_on_user_id_and_exercise_id_and_passed"
    t.index ["user_id"], name: "index_attempts_on_user_id"
  end

  create_table "class_lessons", force: :cascade do |t|
    t.string "slug", null: false
    t.string "course_code", null: false
    t.integer "lesson_number", null: false
    t.string "title", null: false
    t.string "professor"
    t.integer "minutes"
    t.json "steps", default: [], null: false
    t.json "study_guide", default: [], null: false
    t.json "flashcards", default: [], null: false
    t.json "homework", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_code", "lesson_number"], name: "index_class_lessons_on_course_code_and_lesson_number"
    t.index ["slug"], name: "index_class_lessons_on_slug", unique: true
  end

  create_table "class_progresses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "class_lesson_id", null: false
    t.integer "step_index", default: 0, null: false
    t.datetime "completed_at"
    t.json "quiz_first", default: {}, null: false
    t.integer "hints_used", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["class_lesson_id"], name: "index_class_progresses_on_class_lesson_id"
    t.index ["user_id", "class_lesson_id"], name: "index_class_progresses_on_user_id_and_class_lesson_id", unique: true
    t.index ["user_id"], name: "index_class_progresses_on_user_id"
  end

  create_table "course_records", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "position", default: 0, null: false
    t.string "code", null: false
    t.string "title", null: false
    t.string "professor"
    t.string "status"
    t.integer "lessons_done", default: 0, null: false
    t.decimal "hours_logged", precision: 7, scale: 1, default: "0.0", null: false
    t.integer "hours_target"
    t.string "grade"
    t.string "next_lesson"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "code"], name: "index_course_records_on_user_id_and_code", unique: true
    t.index ["user_id"], name: "index_course_records_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug"
    t.string "tagline"
    t.text "description"
    t.boolean "published", default: false, null: false
    t.string "level"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tutor_name"
    t.text "tutor_bio"
    t.string "hours"
    t.text "rubric"
    t.text "outcomes"
    t.index ["slug"], name: "index_courses_on_slug", unique: true
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "course_id", null: false
    t.string "source", default: "self", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["user_id", "course_id"], name: "index_enrollments_on_user_id_and_course_id", unique: true
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "exercises", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.string "course_code", null: false
    t.integer "lesson_number", null: false
    t.string "lesson_label"
    t.string "weak_spot"
    t.string "language", default: "ruby", null: false
    t.text "prompt"
    t.text "starter_code"
    t.json "checks", default: [], null: false
    t.json "hints", default: [], null: false
    t.boolean "open_to_all", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_exercises_on_slug", unique: true
  end

  create_table "homework_submissions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "class_lesson_id", null: false
    t.integer "task_index", null: false
    t.text "work", null: false
    t.datetime "submitted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["class_lesson_id"], name: "index_homework_submissions_on_class_lesson_id"
    t.index ["user_id", "class_lesson_id", "task_index"], name: "index_homework_on_user_lesson_task", unique: true
    t.index ["user_id"], name: "index_homework_submissions_on_user_id"
  end

  create_table "invites", force: :cascade do |t|
    t.string "token", null: false
    t.string "note"
    t.integer "created_by_id", null: false
    t.integer "used_by_id"
    t.datetime "used_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["token"], name: "index_invites_on_token", unique: true
    t.index ["used_by_id"], name: "index_invites_on_used_by_id"
  end

  create_table "lesson_completions", force: :cascade do |t|
    t.integer "enrollment_id", null: false
    t.integer "lesson_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "lesson_id"], name: "index_lesson_completions_on_enrollment_id_and_lesson_id", unique: true
    t.index ["enrollment_id"], name: "index_lesson_completions_on_enrollment_id"
    t.index ["lesson_id"], name: "index_lesson_completions_on_lesson_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.integer "course_id", null: false
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "position"], name: "index_lessons_on_course_id_and_position", unique: true
    t.index ["course_id"], name: "index_lessons_on_course_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "study_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "studied_on", null: false
    t.integer "minutes", null: false
    t.string "course_code"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "manual", null: false
    t.integer "seconds", default: 0, null: false
    t.string "activity"
    t.index ["user_id", "studied_on"], name: "index_study_sessions_on_user_id_and_studied_on"
    t.index ["user_id"], name: "index_study_sessions_on_user_id"
  end

  create_table "transcript_snapshots", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "day_one"
    t.integer "current_day"
    t.string "phase"
    t.decimal "hours_logged", precision: 7, scale: 1, default: "0.0", null: false
    t.integer "stage_hours_target"
    t.string "next_gate_name"
    t.integer "next_gate_day"
    t.string "next_gate_goal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_transcript_snapshots_on_user_id", unique: true
  end

  create_table "tutor_messages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "lesson_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "pending", default: false, null: false
    t.index ["lesson_id"], name: "index_tutor_messages_on_lesson_id"
    t.index ["user_id"], name: "index_tutor_messages_on_user_id"
  end

  create_table "user_badges", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "key", null: false
    t.datetime "earned_at", null: false
    t.datetime "seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "key"], name: "index_user_badges_on_user_id_and_key", unique: true
    t.index ["user_id"], name: "index_user_badges_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.integer "role", default: 0, null: false
    t.boolean "share_in_study_hall", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "attempts", "exercises"
  add_foreign_key "attempts", "users"
  add_foreign_key "class_progresses", "class_lessons"
  add_foreign_key "class_progresses", "users"
  add_foreign_key "course_records", "users"
  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "users"
  add_foreign_key "homework_submissions", "class_lessons"
  add_foreign_key "homework_submissions", "users"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "invites", "users", column: "used_by_id"
  add_foreign_key "lesson_completions", "enrollments"
  add_foreign_key "lesson_completions", "lessons"
  add_foreign_key "lessons", "courses"
  add_foreign_key "sessions", "users"
  add_foreign_key "study_sessions", "users"
  add_foreign_key "transcript_snapshots", "users"
  add_foreign_key "tutor_messages", "lessons"
  add_foreign_key "tutor_messages", "users"
  add_foreign_key "user_badges", "users"
end
