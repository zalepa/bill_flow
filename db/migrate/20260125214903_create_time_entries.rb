class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.belongs_to :project, null: false, foreign_key: true
      t.text :description, null: false # we require a description to avoid bad billing practices
      t.datetime :started_at
      t.datetime :ended_at
      t.boolean :billable, default: true, null: false # we do not allow null to avoid ambiguity with `false`

      t.timestamps
    end
  end
end
