# Every course is now owned, never free to start (docs in the PR that added this).
#
# * courses.code ties a classroom course (the ClassLesson rows that share a
#   course code, like "CS 101") to a Course record, so the owner can grant it.
#   db/seeds.rb fills it in (Catalog.sync_courses!) on every start.
# * gifts: a course bought for someone else, or given by the owner, waiting
#   to be claimed with a one-time link.
# * enrollments made by Stripe are now called "purchase".
# * Courses that students started for free ("self") stop being open to them.
#   The records stay, revoked, so the owner can see them and give access back.
#   The owner's own enrollments are left alone (the owner sees everything).
class StrictCourseAccess < ActiveRecord::Migration[8.1]
  def up
    add_column :courses, :code, :string
    add_index :courses, :code, unique: true

    create_table :gifts do |t|
      t.references :course, null: false, foreign_key: true
      t.string :recipient_email, null: false
      t.references :purchaser, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :emailed_at
      t.datetime :redeemed_at
      t.references :redeemed_by, foreign_key: { to_table: :users }
      t.datetime :revoked_at
      t.string :revoke_reason
      t.integer :amount_cents
      t.string :stripe_session_id
      t.string :payment_intent_id
      t.datetime :terms_accepted_at
      t.timestamps
    end
    add_index :gifts, :token_digest, unique: true
    add_index :gifts, :stripe_session_id, unique: true
    add_index :gifts, :payment_intent_id

    add_reference :enrollments, :gift, foreign_key: true

    execute "UPDATE enrollments SET source = 'purchase' WHERE source = 'stripe'"
    execute <<~SQL
      UPDATE enrollments SET revoked_at = CURRENT_TIMESTAMP, revoke_reason = 'free access ended'
      WHERE source = 'self' AND revoked_at IS NULL
        AND user_id IN (SELECT id FROM users WHERE role <> 1)
    SQL
  end

  def down
    execute "UPDATE enrollments SET source = 'stripe' WHERE source = 'purchase'"
    remove_reference :enrollments, :gift, foreign_key: true
    drop_table :gifts
    remove_index :courses, :code
    remove_column :courses, :code
  end
end
