class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.string :source, null: false, default: "free"
      t.integer :amount_cents, null: false, default: 0
      t.string :stripe_session_id

      t.timestamps
    end
    add_index :enrollments, [ :user_id, :course_id ], unique: true
    add_index :enrollments, :stripe_session_id
  end
end
