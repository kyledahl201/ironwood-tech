class AddCatalogFieldsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :hours, :string
    add_column :courses, :rubric, :text
    add_column :courses, :outcomes, :text
    # nil price means "not on sale yet": shown as "Price coming soon", no checkout.
    change_column_null :courses, :price_cents, true
    change_column_default :courses, :price_cents, from: 0, to: nil
  end
end
