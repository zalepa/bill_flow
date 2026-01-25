class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.belongs_to :client, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :hourly_rate, default: 0
      t.integer :status, default: 0

      t.timestamps
    end
    add_index :projects, :name
  end
end
