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
    t.index ["correlation_id"], name: "index_solid_observer_queue_events_on_correlation_id", where: "correlation_id IS NOT NULL"
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
end
