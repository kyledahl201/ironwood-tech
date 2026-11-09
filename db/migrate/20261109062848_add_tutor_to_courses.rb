class AddTutorToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :tutor_name, :string
    add_column :courses, :tutor_bio, :text
  end
end
