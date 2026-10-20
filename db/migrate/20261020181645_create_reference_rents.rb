class CreateReferenceRents < ActiveRecord::Migration[8.1]
  def change
    create_table :reference_rents do |t|
      t.integer :year, null: false
      t.integer :district_id, null: false # id_quartier (1..80)
      t.string :district_name, null: false # nom_quartier
      t.integer :zone_id, null: false # id_zone (1..14)
      t.integer :rooms, null: false # 1..4, 4 means "4 or more"
      t.string :construction_period, null: false
      t.boolean :furnished, null: false
      # Rents in €/m²: decimal, never float, for money
      t.decimal :min_per_sqm, precision: 8, scale: 2, null: false
      t.decimal :ref_per_sqm, precision: 8, scale: 2, null: false
      t.decimal :max_per_sqm, precision: 8, scale: 2, null: false

      t.timestamps
    end

    # Natural key of a rent profile. Makes the import idempotent (upsert_all unique_by)
    # and serves comparison lookups and per-year reports (year is the leading column).
    add_index :reference_rents,
              %i[year district_id rooms construction_period furnished],
              unique: true, name: "idx_reference_rents_natural_key"

    # Integrity guaranteed by Postgres, even for writes that skip validations (upsert_all)
    add_check_constraint :reference_rents, "rooms BETWEEN 1 AND 4", name: "reference_rents_rooms_range"
    add_check_constraint :reference_rents,
                         "construction_period IN ('before_1946', '1946_1970', '1971_1990', 'after_1990')",
                         name: "reference_rents_construction_period_values"
    add_check_constraint :reference_rents,
                         "min_per_sqm > 0 AND min_per_sqm <= ref_per_sqm AND ref_per_sqm <= max_per_sqm",
                         name: "reference_rents_rent_bounds"
  end
end
