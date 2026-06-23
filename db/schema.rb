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

ActiveRecord::Schema[8.1].define(version: 2026_06_23_100949) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "inboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "unread_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["unread_count"], name: "idx_inboxes_unread_count"
    t.index ["user_id"], name: "index_inboxes_on_user_id"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.uuid "inbox_id"
    t.uuid "outbox_id"
    t.uuid "parent_message_id"
    t.uuid "prescription_id"
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.integer "routing_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["inbox_id", "created_at"], name: "idx_messages_inbox_created_at", order: { created_at: :desc }
    t.index ["inbox_id", "prescription_id", "created_at"], name: "idx_messages_inbox_prescription_created"
    t.index ["inbox_id", "read", "created_at"], name: "idx_messages_inbox_unread_created", order: { created_at: :desc }
    t.index ["inbox_id", "read_at"], name: "idx_messages_inbox_unread", where: "(read_at IS NULL)"
    t.index ["outbox_id", "created_at"], name: "idx_messages_outbox_created_at", order: { created_at: :desc }
    t.index ["parent_message_id", "created_at"], name: "idx_messages_parent_thread", order: { created_at: :desc }
    t.index ["parent_message_id", "created_at"], name: "idx_messages_root_conversations", order: { created_at: :desc }, where: "(parent_message_id IS NULL)"
    t.index ["prescription_id", "created_at"], name: "index_messages_on_prescription_id_and_created_at"
    t.index ["prescription_id"], name: "index_messages_on_prescription_id"
    t.index ["routing_type", "created_at"], name: "index_messages_on_routing_type_and_created_at"
    t.index ["routing_type"], name: "index_messages_on_routing_type"
    t.index ["status", "created_at"], name: "index_messages_on_status_and_created_at"
    t.index ["status", "read"], name: "idx_messages_status_read"
  end

  create_table "outboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["user_id"], name: "index_outboxes_on_user_id"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "last_retry_at"
    t.string "payment_provider", default: "flaky", null: false
    t.integer "retry_count", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["retry_count"], name: "index_payments_on_retry_count"
    t.index ["status", "created_at"], name: "index_payments_on_status_and_created_at"
    t.index ["status", "retry_count", "created_at"], name: "idx_payments_status_retry_created"
    t.index ["user_id", "status", "created_at"], name: "idx_payments_user_status_created"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "prescriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "payment_id"
    t.string "pdf_url"
    t.datetime "ready_at"
    t.datetime "requested_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["payment_id"], name: "index_prescriptions_on_payment_id"
    t.index ["requested_at"], name: "index_prescriptions_on_requested_at"
    t.index ["status"], name: "index_prescriptions_on_status"
    t.index ["user_id", "created_at"], name: "index_prescriptions_on_user_id_and_created_at"
    t.index ["user_id", "status", "created_at"], name: "idx_prescriptions_user_status_created"
    t.index ["user_id", "status"], name: "index_prescriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
  end

  create_table "solid_observer_cable_events", force: :cascade do |t|
    t.string "broadcasting_digest", limit: 64
    t.string "channel_class", limit: 255
    t.float "duration"
    t.string "error_class", limit: 255
    t.text "error_message"
    t.string "event_type", limit: 64, null: false
    t.text "metadata"
    t.datetime "recorded_at", null: false
    t.index ["broadcasting_digest"], name: "index_solid_observer_cable_events_on_broadcasting_digest"
    t.index ["channel_class"], name: "index_solid_observer_cable_events_on_channel_class"
    t.index ["error_class"], name: "index_solid_observer_cable_events_on_error_class"
    t.index ["event_type"], name: "index_solid_observer_cable_events_on_event_type"
    t.index ["recorded_at"], name: "index_solid_observer_cable_events_on_recorded_at"
  end

  create_table "solid_observer_cable_metrics", force: :cascade do |t|
    t.bigint "broadcasts_count", default: 0, null: false
    t.bigint "confirmations_count", default: 0, null: false
    t.bigint "errors_count", default: 0, null: false
    t.bigint "perform_actions_count", default: 0, null: false
    t.datetime "period_start", null: false
    t.bigint "rejections_count", default: 0, null: false
    t.bigint "transmissions_count", default: 0, null: false
    t.index ["period_start"], name: "idx_solid_observer_cable_metrics_unique", unique: true
  end

  create_table "solid_observer_cache_events", force: :cascade do |t|
    t.float "duration"
    t.string "error_class", limit: 255
    t.text "error_message"
    t.string "event_type", limit: 64, null: false
    t.boolean "hit"
    t.string "key_digest", limit: 64, null: false
    t.text "metadata"
    t.datetime "recorded_at", null: false
    t.index ["error_class"], name: "index_solid_observer_cache_events_on_error_class"
    t.index ["event_type", "recorded_at"], name: "idx_on_event_type_recorded_at_fb6f5a14c6", order: { recorded_at: :desc }
    t.index ["event_type"], name: "index_solid_observer_cache_events_on_event_type"
    t.index ["hit"], name: "index_solid_observer_cache_events_on_hit"
    t.index ["key_digest"], name: "index_solid_observer_cache_events_on_key_digest"
    t.index ["recorded_at"], name: "index_solid_observer_cache_events_on_recorded_at"
  end

  create_table "solid_observer_cache_metrics", force: :cascade do |t|
    t.float "duration_total", default: 0.0, null: false
    t.bigint "errors_count", default: 0, null: false
    t.string "event_type", limit: 64, null: false
    t.bigint "hits_count", default: 0, null: false
    t.bigint "misses_count", default: 0, null: false
    t.bigint "operations_count", default: 0, null: false
    t.datetime "period_start", null: false
    t.index ["event_type", "period_start"], name: "idx_solid_observer_cache_metrics_unique", unique: true
    t.index ["period_start"], name: "index_solid_observer_cache_metrics_on_period_start"
  end

  create_table "solid_observer_metrics", force: :cascade do |t|
    t.string "metric_name", limit: 50, null: false
    t.datetime "period_start", null: false
    t.string "period_type", limit: 10, null: false
    t.bigint "value", default: 0, null: false
    t.index ["metric_name", "period_start", "period_type"], name: "idx_solid_observer_metrics_unique", unique: true
  end

  create_table "solid_observer_queue_events", force: :cascade do |t|
    t.string "correlation_id", limit: 64
    t.float "duration"
    t.string "event_type", limit: 50, null: false
    t.string "job_class", limit: 100
    t.text "metadata"
    t.string "queue_name", limit: 50
    t.datetime "recorded_at", null: false
    t.index ["correlation_id"], name: "index_solid_observer_queue_events_on_correlation_id", where: "(correlation_id IS NOT NULL)"
    t.index ["event_type"], name: "index_solid_observer_queue_events_on_event_type"
    t.index ["job_class", "recorded_at"], name: "index_solid_observer_queue_events_on_job_class_and_recorded_at", order: { recorded_at: :desc }
    t.index ["queue_name", "recorded_at"], name: "idx_on_queue_name_recorded_at_4e0f671e8c", order: { recorded_at: :desc }
    t.index ["recorded_at"], name: "index_solid_observer_queue_events_on_recorded_at"
  end

  create_table "solid_observer_storage_info", force: :cascade do |t|
    t.string "component", default: "queue_observer", null: false
    t.bigint "db_size_bytes", null: false
    t.bigint "event_count", null: false
    t.datetime "recorded_at", null: false
    t.index ["component"], name: "index_solid_observer_storage_info_on_component"
    t.index ["recorded_at"], name: "index_solid_observer_storage_info_on_recorded_at"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "first_name"
    t.boolean "is_admin", default: false, null: false
    t.boolean "is_doctor", default: false, null: false
    t.boolean "is_patient", default: true, null: false
    t.string "last_name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "messages", "messages", column: "parent_message_id", on_delete: :nullify
  add_foreign_key "messages", "prescriptions"
  add_foreign_key "prescriptions", "payments"
  add_foreign_key "prescriptions", "users"
end
