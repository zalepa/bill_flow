class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.belongs_to :client, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :status, default: 0 # e.g., 0: draft, 1: sent, 2: paid, 3: overdue
      t.date :issued_on # leaving null to allow for drafts
      t.date :due_on # leaving null to allow for drafts
      t.text :notes, default: ""

      t.timestamps
    end

    add_index :invoices, [ :client_id, :number ], unique: true
    add_index :invoices, :status
  end
end
