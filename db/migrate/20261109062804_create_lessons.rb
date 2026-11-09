class CreateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :body

      t.timestamps
    end
    add_index :lessons, [ :course_id, :position ], unique: true
  end
end
