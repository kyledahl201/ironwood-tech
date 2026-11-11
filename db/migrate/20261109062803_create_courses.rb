class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title, null: false
      t.string :slug
      t.string :tagline
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.boolean :published, null: false, default: false
      t.string :level
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :courses, :slug, unique: true
  end
end
