class CreateTutorMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :tutor_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end
  end
end
