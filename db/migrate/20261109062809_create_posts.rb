class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.string :slug
      t.text :summary
      t.text :body
      t.datetime :published_at

      t.timestamps
    end
    add_index :posts, :slug, unique: true
  end
end
