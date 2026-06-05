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

ActiveRecord::Schema[8.1].define(version: 2026_06_05_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "bookmarks", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "document_id"
    t.string "document_type"
    t.binary "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id", null: false
    t.string "user_type"
    t.index ["document_id"], name: "index_bookmarks_on_document_id"
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "cosmetic"
    t.datetime "created_at", null: false
    t.string "raw"
    t.datetime "updated_at", null: false
    t.index ["raw"], name: "index_groups_on_raw", unique: true
  end

  create_table "iptc_ingests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_key"
    t.bigint "load_report_id", null: false
    t.string "source_filename"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "warnings", default: "[]"
    t.string "work_pid"
    t.index ["load_report_id"], name: "index_iptc_ingests_on_load_report_id"
  end

  create_table "load_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "loader_id"
    t.string "parent_collection_id"
    t.string "source_filename"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["loader_id"], name: "index_load_reports_on_loader_id"
  end

  create_table "loaders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "group", null: false
    t.integer "kind", default: 0, null: false
    t.string "root_collection", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_loaders_on_slug", unique: true
  end

  create_table "searches", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.binary "query_params"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.string "user_type"
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "xml_ingests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_key"
    t.bigint "load_report_id", null: false
    t.string "source_filename"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "warnings", default: "[]"
    t.string "work_pid"
    t.index ["load_report_id"], name: "index_xml_ingests_on_load_report_id"
  end

  add_foreign_key "iptc_ingests", "load_reports"
  add_foreign_key "load_reports", "loaders"
  add_foreign_key "xml_ingests", "load_reports"
end
