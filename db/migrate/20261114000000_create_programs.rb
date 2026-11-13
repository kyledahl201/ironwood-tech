# Programs: what a buyer gets. A program holds classes (courses), and owning a
# program (bought, given by the owner, or a claimed gift) opens every class in
# it. Program.sync! (db/seeds.rb) makes the programs and places the courses.
#
# Safe on the live SQLite database: two new tables, three new nullable
# columns (plain ALTER TABLE ADD COLUMN, no table copy), and gifts.course_id
# allowed to be empty for a gift of a whole program (SQLite copies the small
# gifts table to do this; every row and id is kept). Nothing existing changes
# meaning: every course enrollment still opens what it opened before.
class CreatePrograms < ActiveRecord::Migration[8.1]
  def up
    create_table :programs do |t|
      t.string :slug, null: false
      t.string :tier, null: false
      t.string :title, null: false
      t.string :tagline
      t.text :description
      t.integer :position, default: 0, null: false
      t.integer :price_cents
      t.boolean :published, default: true, null: false
      t.timestamps
      t.index :slug, unique: true
    end

    create_table :program_enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.string :source, null: false
      t.references :gift, foreign_key: true
      t.integer :amount_cents
      t.string :stripe_session_id
      t.string :payment_intent_id
      t.datetime :terms_accepted_at
      t.datetime :revoked_at
      t.string :revoke_reason
      t.timestamps
      t.index [ :user_id, :program_id ], unique: true
      t.index :stripe_session_id, unique: true
      t.index :payment_intent_id
    end

    # No foreign-key constraints on these three: adding one to an existing
    # SQLite table means copying the whole table.
    add_reference :courses, :program, index: true
    add_reference :enrollments, :program_enrollment, index: true
    add_reference :gifts, :program, index: true
    change_column_null :gifts, :course_id, true
  end

  def down
    if select_value("SELECT COUNT(*) FROM gifts WHERE course_id IS NULL").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "Gifts of whole programs exist. Rolling back would lose them; end or delete those gifts first."
    end
    change_column_null :gifts, :course_id, false
    remove_reference :gifts, :program, index: true
    remove_reference :enrollments, :program_enrollment, index: true
    remove_reference :courses, :program, index: true
    drop_table :program_enrollments
    drop_table :programs
  end
end
