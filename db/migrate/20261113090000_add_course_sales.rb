# Ironwood sells courses again. This brings back the selling columns that
# 20261111040051 removed, without changing what anyone can open today:
#
# * courses.paid is false for every existing course, so they stay free to
#   start for portal members exactly as before.
# * enrollments.revoked_at is empty for every existing enrollment, so they all
#   stay active.
# * users.customer_only is false for every existing user, so they keep the
#   whole portal. It is set only on accounts created by buying a course.
class AddCourseSales < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :paid, :boolean, null: false, default: false
    add_column :courses, :price_cents, :integer

    add_column :enrollments, :amount_cents, :integer
    add_column :enrollments, :stripe_session_id, :string
    add_column :enrollments, :payment_intent_id, :string
    add_column :enrollments, :revoked_at, :datetime
    add_column :enrollments, :revoke_reason, :string
    add_column :enrollments, :terms_accepted_at, :datetime
    add_index :enrollments, :stripe_session_id, unique: true
    add_index :enrollments, :payment_intent_id

    add_column :users, :customer_only, :boolean, null: false, default: false
  end
end
