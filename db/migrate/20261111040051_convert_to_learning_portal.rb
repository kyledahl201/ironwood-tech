# Ironwood is a non-profit personal university again: no sales, invite-only
# accounts, a private transcript record, and self-logged study time.
class ConvertToLearningPortal < ActiveRecord::Migration[8.1]
  def change
    drop_table :leads do |t|
      t.string :name
      t.string :email, null: false
      t.string :company
      t.string :job_title
      t.text :message
      t.string :kind, null: false, default: "consulting"
      t.string :status, null: false, default: "new"
      t.timestamps
    end
    drop_table :posts do |t|
      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :summary
      t.text :body
      t.datetime :published_at
      t.timestamps
    end

    remove_column :courses, :price_cents, :integer
    remove_index :enrollments, :payment_intent_id
    remove_index :enrollments, :stripe_session_id
    remove_column :enrollments, :amount_cents, :integer
    remove_column :enrollments, :stripe_session_id, :string
    remove_column :enrollments, :payment_intent_id, :string
    remove_column :enrollments, :revoked_at, :datetime
    remove_column :enrollments, :revoke_reason, :string
    remove_column :enrollments, :terms_accepted_at, :datetime
    change_column_default :enrollments, :source, from: "free", to: "self"

    add_column :users, :share_in_study_hall, :boolean, null: false, default: false

    create_table :invites do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :note
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :used_by, foreign_key: { to_table: :users }
      t.datetime :used_at
      t.datetime :expires_at, null: false
      t.timestamps
    end

    create_table :study_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :studied_on, null: false
      t.integer :minutes, null: false
      t.string :course_code
      t.string :note
      t.timestamps
    end
    add_index :study_sessions, [ :user_id, :studied_on ]

    # One row per transcript import: the headline numbers from TRANSCRIPT.md.
    create_table :transcript_snapshots do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.date :day_one
      t.integer :current_day
      t.string :phase
      t.decimal :hours_logged, precision: 7, scale: 1, default: 0, null: false
      t.integer :stage_hours_target
      t.string :next_gate_name
      t.integer :next_gate_day
      t.string :next_gate_goal
      t.timestamps
    end

    create_table :course_records do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :code, null: false
      t.string :title, null: false
      t.string :professor
      t.string :status
      t.integer :lessons_done, null: false, default: 0
      t.decimal :hours_logged, precision: 7, scale: 1, default: 0, null: false
      t.integer :hours_target
      t.string :grade
      t.string :next_lesson
      t.timestamps
    end
    add_index :course_records, [ :user_id, :code ], unique: true
  end
end
