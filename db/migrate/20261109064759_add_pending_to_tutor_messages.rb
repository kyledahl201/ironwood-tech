class AddPendingToTutorMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :tutor_messages, :pending, :boolean, default: false, null: false
  end
end
