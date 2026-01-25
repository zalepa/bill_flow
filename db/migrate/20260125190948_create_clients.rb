class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name,    null: false
      t.string :email,   null: false
      t.string :company, null: false
      t.string :phone
      t.text   :notes

      t.timestamps
    end

    add_index :clients, :name                 # will search on name
    add_index :clients, :company              # will search on company
    add_index :clients, :email, unique: true  # email must be unique
  end
end
