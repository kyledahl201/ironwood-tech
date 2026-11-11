class CreateLab < ActiveRecord::Migration[8.1]
  def change
    create_table :exercises do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :title, null: false
      t.string :course_code, null: false
      t.integer :lesson_number, null: false
      t.string :lesson_label
      t.string :weak_spot
      t.string :language, null: false, default: "ruby"
      t.text :prompt
      t.text :starter_code
      t.json :checks, null: false, default: []
      t.json :hints, null: false, default: []
      t.boolean :open_to_all, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.text :code, null: false
      t.boolean :passed, null: false, default: false
      t.integer :checks_passed, null: false, default: 0
      t.integer :hints_used, null: false, default: 0
      t.timestamps
    end
    add_index :attempts, [ :user_id, :exercise_id, :passed ]

    create_table :user_badges do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.datetime :earned_at, null: false
      t.datetime :seen_at
      t.timestamps
    end
    add_index :user_badges, [ :user_id, :key ], unique: true
  end
end
