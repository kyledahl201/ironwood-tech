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

ActiveRecord::Schema[8.1].define(version: 2026_11_09_064759) do
  create_table "courses", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug"
    t.string "tagline"
    t.text "description"
    t.integer "price_cents"
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
    t.string "source", default: "free", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "stripe_session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_intent_id"
    t.datetime "revoked_at"
    t.string "revoke_reason"
    t.datetime "terms_accepted_at"
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["payment_intent_id"], name: "index_enrollments_on_payment_intent_id"
    t.index ["stripe_session_id"], name: "index_enrollments_on_stripe_session_id"
    t.index ["user_id", "course_id"], name: "index_enrollments_on_user_id_and_course_id", unique: true
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "name"
    t.string "email", null: false
    t.string "company"
    t.string "job_title"
    t.text "message"
    t.string "kind", default: "consulting", null: false
    t.string "status", default: "new", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug"
    t.text "summary"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
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

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.integer "role", default: 0, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "users"
  add_foreign_key "lesson_completions", "enrollments"
  add_foreign_key "lesson_completions", "lessons"
  add_foreign_key "lessons", "courses"
  add_foreign_key "sessions", "users"
  add_foreign_key "tutor_messages", "lessons"
  add_foreign_key "tutor_messages", "users"
end
