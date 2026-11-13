# Kyle approved "Kyle Dahl" as the instructor name on Nov 13, 2026. The seed
# never rewrites text already in the database, so this swaps the placeholder
# in any course text that still has it. Text the owner already edited by hand
# no longer contains the placeholder and is left alone.
class FillPx1InstructorName < ActiveRecord::Migration[8.1]
  PLACEHOLDER = "[INSTRUCTOR NAME]".freeze
  NAME = "Kyle Dahl".freeze
  COLUMNS = %w[description tagline tutor_bio].freeze

  def up
    COLUMNS.each do |column|
      execute <<~SQL.squish
        UPDATE courses
        SET #{column} = REPLACE(#{column}, #{quote(PLACEHOLDER)}, #{quote(NAME)})
        WHERE #{column} LIKE #{quote("%#{PLACEHOLDER}%")}
      SQL
    end
  end

  def down
    # One-way text fix; nothing to undo.
  end

  private

  def quote(value) = connection.quote(value)
end
