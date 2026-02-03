class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.belongs_to :invoice, null: false, foreign_key: true
      t.text :description, null: false # require something else clients will question it
      t.integer :quantity, default: 1 # if less than one, should not be billed (but confirm if this is desired behavior)
      t.integer :unit_price, default: 0 # in cents to avoid floating point issues, allow zero to show free item
      t.timestamps
    end
  end
end
