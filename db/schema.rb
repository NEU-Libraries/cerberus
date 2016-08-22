# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20160817194158) do

  create_table "aggregated_statistics", :force => true do |t|
    t.string   "object_type"
    t.string   "pid"
    t.integer  "views",                               :default => 0
    t.integer  "downloads",                           :default => 0
    t.integer  "streams",                             :default => 0
    t.integer  "loader_uploads",                      :default => 0
    t.integer  "user_uploads",                        :default => 0
    t.integer  "form_edits",                          :default => 0
    t.integer  "xml_edits",                           :default => 0
    t.integer  "size_increase",          :limit => 8, :default => 0
    t.datetime "processed_at"
    t.integer  "spreadsheet_load_edits",              :default => 0
    t.integer  "xml_load_edits",                      :default => 0
  end

  create_table "bookmarks", :force => true do |t|
    t.integer  "user_id",     :null => false
    t.string   "document_id"
    t.string   "title"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "user_type"
  end

  create_table "checksum_audit_logs", :force => true do |t|
    t.string   "pid"
    t.string   "dsid"
    t.string   "version"
    t.integer  "pass"
    t.string   "expected_result"
    t.string   "actual_result"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "checksum_audit_logs", ["pid", "dsid"], :name => "by_pid_and_dsid"

  create_table "conversations", :force => true do |t|
    t.string   "subject",    :default => ""
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  create_table "domain_terms", :force => true do |t|
    t.string "model"
    t.string "term"
  end

  add_index "domain_terms", ["model", "term"], :name => "terms_by_model_and_term"

  create_table "domain_terms_local_authorities", :id => false, :force => true do |t|
    t.integer "domain_term_id"
    t.integer "local_authority_id"
  end

  add_index "domain_terms_local_authorities", ["domain_term_id", "local_authority_id"], :name => "dtla_by_ids2"
  add_index "domain_terms_local_authorities", ["local_authority_id", "domain_term_id"], :name => "dtla_by_ids1"

  create_table "file_size_graphs", :force => true do |t|
    t.text     "json_values", :limit => 4294967295
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
  end

  create_table "follows", :force => true do |t|
    t.integer  "followable_id",                      :null => false
    t.string   "followable_type",                    :null => false
    t.integer  "follower_id",                        :null => false
    t.string   "follower_type",                      :null => false
    t.boolean  "blocked",         :default => false, :null => false
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
  end

  add_index "follows", ["followable_id", "followable_type"], :name => "fk_followables"
  add_index "follows", ["follower_id", "follower_type"], :name => "fk_follows"

  create_table "impressions", :force => true do |t|
    t.string   "pid"
    t.string   "session_id"
    t.string   "action"
    t.string   "ip_address"
    t.string   "referrer"
    t.string   "status"
    t.string   "user_agent"
    t.boolean  "public",     :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "processed",  :default => false
  end

  add_index "impressions", ["pid"], :name => "index_drs_impressions_on_pid"

  create_table "item_reports", :force => true do |t|
    t.boolean  "validity"
    t.string   "pid"
    t.string   "collection"
    t.string   "title"
    t.text     "iptc"
    t.text     "exception"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.integer  "load_report_id"
    t.string   "original_file"
    t.boolean  "modified",       :default => false
    t.string   "change_type"
    t.boolean  "preview_file",   :default => false
  end

  create_table "load_reports", :force => true do |t|
    t.string   "loader_name"
    t.integer  "number_of_files"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "success_count"
    t.integer  "fail_count"
    t.string   "nuid"
    t.string   "collection"
    t.integer  "modified_count"
    t.string   "comparison_file_pid", :default => ""
    t.string   "preview_file_pid",    :default => ""
    t.boolean  "completed",           :default => false
  end

  create_table "local_authorities", :force => true do |t|
    t.string "name"
  end

  create_table "local_authority_entries", :force => true do |t|
    t.integer "local_authority_id"
    t.string  "label"
    t.string  "uri"
  end

  add_index "local_authority_entries", ["local_authority_id", "label"], :name => "entries_by_term_and_label"
  add_index "local_authority_entries", ["local_authority_id", "uri"], :name => "entries_by_term_and_uri"

  create_table "notifications", :force => true do |t|
    t.string   "type"
    t.text     "body"
    t.string   "subject",              :default => ""
    t.integer  "sender_id"
    t.string   "sender_type"
    t.integer  "conversation_id"
    t.boolean  "draft",                :default => false
    t.datetime "updated_at",                              :null => false
    t.datetime "created_at",                              :null => false
    t.integer  "notified_object_id"
    t.string   "notified_object_type"
    t.string   "notification_code"
    t.string   "attachment"
  end

  add_index "notifications", ["conversation_id"], :name => "index_notifications_on_conversation_id"

  create_table "receipts", :force => true do |t|
    t.integer  "receiver_id"
    t.string   "receiver_type"
    t.integer  "notification_id",                                  :null => false
    t.boolean  "is_read",                       :default => false
    t.boolean  "trashed",                       :default => false
    t.boolean  "deleted",                       :default => false
    t.string   "mailbox_type",    :limit => 25
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  add_index "receipts", ["notification_id"], :name => "index_receipts_on_notification_id"

  create_table "searches", :force => true do |t|
    t.text     "query_params"
    t.integer  "user_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.string   "user_type"
  end

  add_index "searches", ["user_id"], :name => "index_searches_on_user_id"

  create_table "sentinels", :force => true do |t|
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.text     "audio"
    t.text     "audio_master"
    t.text     "image_large"
    t.text     "image_master"
    t.text     "image_medium"
    t.text     "image_small"
    t.text     "msexcel"
    t.text     "mspowerpoint"
    t.text     "msword"
    t.text     "page"
    t.text     "pdf"
    t.text     "text"
    t.text     "video"
    t.text     "video_master"
    t.text     "zip"
    t.text     "pid_list"
    t.string   "set_pid"
    t.boolean  "permanent"
    t.string   "email"
    t.text     "core_file"
  end

  create_table "single_use_links", :force => true do |t|
    t.string   "downloadKey"
    t.string   "path"
    t.string   "itemId"
    t.datetime "expires"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "subject_local_authority_entries", :force => true do |t|
    t.string "label"
    t.string "lowerLabel"
    t.string "url"
  end

  add_index "subject_local_authority_entries", ["lowerLabel"], :name => "entries_by_lower_label"

  create_table "upload_alerts", :force => true do |t|
    t.string   "content_type"
    t.string   "title"
    t.string   "depositor_name"
    t.string   "depositor_email"
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
    t.string   "pid"
    t.boolean  "notified"
    t.string   "change_type"
    t.string   "collection_pid"
    t.string   "collection_title"
    t.string   "editor_nuid"
    t.string   "load_type",        :default => ""
  end

  add_index "upload_alerts", ["content_type"], :name => "index_upload_alerts_on_type"

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",     :null => false
    t.string   "encrypted_password",     :default => "",     :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.boolean  "guest",                  :default => false
    t.string   "facebook_handle"
    t.string   "twitter_handle"
    t.string   "googleplus_handle"
    t.string   "display_name"
    t.string   "address"
    t.string   "admin_area"
    t.string   "title"
    t.string   "office"
    t.string   "chat_id"
    t.string   "website"
    t.string   "affiliation"
    t.string   "telephone"
    t.text     "group_list"
    t.datetime "groups_last_update"
    t.string   "role"
    t.string   "department"
    t.string   "nuid"
    t.string   "full_name"
    t.string   "view_pref",              :default => "list"
    t.string   "employee_id"
    t.string   "account_pref",           :default => ""
    t.boolean  "multiple_accounts",      :default => false
    t.integer  "per_page_pref",          :default => 10
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

  create_table "version_committers", :force => true do |t|
    t.string   "obj_id"
    t.string   "datastream_id"
    t.string   "version_id"
    t.string   "committer_login"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "xml_alerts", :force => true do |t|
    t.string   "pid"
    t.string   "name"
    t.string   "email"
    t.string   "title"
    t.text     "old_file_str", :limit => 4294967295
    t.text     "new_file_str", :limit => 4294967295
    t.text     "diff",         :limit => 4294967295
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "notified"
  end

end
