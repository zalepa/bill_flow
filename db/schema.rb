# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_03_155609) do
  create_table "clients", force: :cascade do |t|
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["company"], name: "index_clients_on_company"
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["name"], name: "index_clients_on_name"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on"
    t.date "issued_on"
    t.text "notes", default: ""
    t.integer "number", null: false
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["client_id", "number"], name: "index_invoices_on_client_id_and_number", unique: true
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "invoice_id", null: false
    t.integer "quantity", default: 1
    t.integer "unit_price", default: 0
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "hourly_rate", default: 0
    t.string "name", null: false
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["name"], name: "index_projects_on_name"
  end

  create_table "time_entries", force: :cascade do |t|
    t.boolean "billable", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.datetime "ended_at"
    t.integer "project_id", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_time_entries_on_project_id"
  end

  add_foreign_key "invoices", "clients"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "projects", "clients"
  add_foreign_key "time_entries", "projects"
end
