require "rails_helper"

RSpec.describe ReferenceRent do
  it "has a valid factory" do
    expect(build(:reference_rent)).to be_valid
  end

  describe "validations" do
    it "rejects rooms outside 1..4" do
      expect(build(:reference_rent, rooms: 5)).not_to be_valid
    end

    it "rejects an unknown construction period" do
      rent = build(:reference_rent, construction_period: "medieval")

      expect(rent).not_to be_valid
      expect(rent.errors[:construction_period]).to be_present
    end

    it "rejects bounds that are not ordered" do
      rent = build(:reference_rent, min_per_sqm: 30, ref_per_sqm: 26.1)

      expect(rent).not_to be_valid
      expect(rent.errors[:base]).to include("rents must satisfy min <= ref <= max")
    end
  end

  describe "database constraints" do
    # Validations can be bypassed (upsert_all, update_columns, concurrent requests).
    # These specs prove Postgres still protects the data.
    it "rejects a duplicate natural key" do
      existing = create(:reference_rent)
      duplicate = build(:reference_rent, district_id: existing.district_id)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects rooms outside 1..4 even without validations" do
      expect { build(:reference_rent, rooms: 7).save(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid, /reference_rents_rooms_range/)
    end
  end

  describe ".current_year" do
    it "returns the most recent year in the table" do
      create(:reference_rent, year: 2024)
      create(:reference_rent, year: 2025)

      expect(described_class.current_year).to eq(2025)
    end
  end
end
