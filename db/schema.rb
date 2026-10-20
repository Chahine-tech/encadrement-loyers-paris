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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_181645) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reference_rents", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "district_id", null: false
    t.string "district_name", null: false
    t.integer "zone_id", null: false
    t.integer "rooms", null: false
    t.string "construction_period", null: false
    t.boolean "furnished", null: false
    t.decimal "min_per_sqm", precision: 8, scale: 2, null: false
    t.decimal "ref_per_sqm", precision: 8, scale: 2, null: false
    t.decimal "max_per_sqm", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "district_id", "rooms", "construction_period", "furnished"], name: "idx_reference_rents_natural_key", unique: true
    t.check_constraint "construction_period::text = ANY (ARRAY['before_1946'::character varying, '1946_1970'::character varying, '1971_1990'::character varying, 'after_1990'::character varying]::text[])", name: "reference_rents_construction_period_values"
    t.check_constraint "min_per_sqm > 0::numeric AND min_per_sqm <= ref_per_sqm AND ref_per_sqm <= max_per_sqm", name: "reference_rents_rent_bounds"
    t.check_constraint "rooms >= 1 AND rooms <= 4", name: "reference_rents_rooms_range"
  end
end
