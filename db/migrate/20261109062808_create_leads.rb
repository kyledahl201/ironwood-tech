class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.string :name
      t.string :email, null: false
      t.string :company
      t.string :job_title
      t.text :message
      t.string :kind, null: false, default: "consulting"
      t.string :status, null: false, default: "new"

      t.timestamps
    end
  end
end
