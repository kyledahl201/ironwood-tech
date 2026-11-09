class AddRevocationToEnrollments < ActiveRecord::Migration[8.1]
  def change
    add_column :enrollments, :payment_intent_id, :string
    add_index :enrollments, :payment_intent_id
    add_column :enrollments, :revoked_at, :datetime
    add_column :enrollments, :revoke_reason, :string
    add_column :enrollments, :terms_accepted_at, :datetime
  end
end
