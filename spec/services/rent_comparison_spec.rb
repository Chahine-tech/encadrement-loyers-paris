require "rails_helper"

RSpec.describe RentComparison do
  # 30 m² → min 549.00 €, ref 783.00 €, max 939.00 €
  let!(:reference) do
    create(:reference_rent,
           year: 2025, district_id: 67, rooms: 2, construction_period: :after_1990, furnished: true,
           min_per_sqm: 18.3, ref_per_sqm: 26.1, max_per_sqm: 31.3)
  end

  let(:params) do
    { district_id: "67", rooms: "2", construction_period: "after_1990", furnished: "true", surface: "30", rent: "800" }
  end

  def compare(**overrides)
    described_class.new(params.merge(overrides)).call
  end

  describe "status" do
    it "is within_range between the min and max legal rents" do
      expect(compare(rent: "800").status).to eq(:within_range)
    end

    it "is above_max when the rent exceeds the max legal rent" do
      expect(compare(rent: "1000").status).to eq(:above_max)
    end

    it "is below_min when the rent is under the min legal rent" do
      expect(compare(rent: "500").status).to eq(:below_min)
    end

    it "treats a rent exactly at the max as legal" do
      expect(compare(rent: "939").status).to eq(:within_range)
    end
  end

  it "computes legal rents for the surface and the excess" do
    result = compare(rent: "1000")

    expect(result).to have_attributes(
      reference_rent: reference, year: 2025,
      min_rent: BigDecimal("549.00"), ref_rent: BigDecimal("783.00"), max_rent: BigDecimal("939.00"),
      rent_per_sqm: BigDecimal("33.33"), excess: BigDecimal("61.00")
    )
  end

  it "reports no excess when the rent is legal" do
    expect(compare(rent: "800").excess).to eq(0)
  end

  it "uses the most recent year by default" do
    older = create(:reference_rent, year: 2024, district_id: 67, rooms: 2,
                                    construction_period: :after_1990, furnished: true)

    expect(compare.reference_rent).to eq(reference)
    expect(compare(year: "2024").reference_rent).to eq(older)
  end

  it "maps 5 rooms and more to the dataset's '4 and more' category" do
    four_rooms = create(:reference_rent, year: 2025, district_id: 67, rooms: 4,
                                         construction_period: :after_1990, furnished: true)

    expect(compare(rooms: "6").reference_rent).to eq(four_rooms)
  end

  it "raises RecordNotFound when no reference matches the profile" do
    expect { compare(district_id: "999") }.to raise_error(ActiveRecord::RecordNotFound)
  end

  describe "validation" do
    # The :decimal type casts "abc" to 0 (like "abc".to_d), so it fails on "greater than 0"
    it "rejects a non-numeric surface" do
      expect { compare(surface: "abc") }.to raise_error(ActiveModel::ValidationError, /Surface must be greater than 0/)
    end

    it "rejects a missing surface" do
      expect { compare(surface: nil) }.to raise_error(ActiveModel::ValidationError, /Surface is not a number/)
    end

    it "rejects a zero or negative rent" do
      expect { compare(rent: "0") }.to raise_error(ActiveModel::ValidationError, /Rent must be greater than 0/)
    end

    it "rejects an unknown construction period" do
      expect { compare(construction_period: "1900") }
        .to raise_error(ActiveModel::ValidationError, /Construction period is not included/)
    end

    it "rejects a furnished value that is not a boolean" do
      expect { compare(furnished: "maybe") }.to raise_error(ActiveModel::ValidationError, /Furnished must be true or false/)
    end

    it "requires furnished to be given" do
      expect { compare(furnished: nil) }.to raise_error(ActiveModel::ValidationError, /Furnished must be true or false/)
    end

    it "collects every error at once" do
      comparison = described_class.new(params.merge(surface: "-1", rent: ""))

      expect(comparison).not_to be_valid
      expect(comparison.errors.attribute_names).to contain_exactly(:surface, :rent)
    end
  end
end
