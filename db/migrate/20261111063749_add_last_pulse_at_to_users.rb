class AddLastPulseAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_pulse_at, :datetime
  end
end
