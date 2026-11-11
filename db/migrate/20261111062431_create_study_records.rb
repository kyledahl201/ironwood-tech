class CreateStudyRecords < ActiveRecord::Migration[8.1]
  def change
    # What a student studied for a lesson outside class: flashcards sorted and
    # questions retried. Time on task is tracked separately.
    create_table :study_records do |t|
      t.references :user, null: false, foreign_key: true
      t.references :class_lesson, null: false, foreign_key: true
      t.json :known_cards, null: false, default: []   # cards marked "got it" in the current pass
      t.integer :cards_again, null: false, default: 0 # times a card was sent back as "again later"
      t.integer :decks_finished, null: false, default: 0
      t.datetime :deck_finished_at
      t.json :retry_first, null: false, default: {}   # question step => was the first retry answer right
      t.datetime :retried_at
      t.timestamps
    end
    add_index :study_records, [ :user_id, :class_lesson_id ], unique: true
  end
end
