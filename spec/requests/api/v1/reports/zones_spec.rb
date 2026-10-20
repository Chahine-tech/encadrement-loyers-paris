require "rails_helper"

RSpec.describe "GET /api/v1/reports/zones", type: :request do
  def rent(district_id, name, zone_id, ref, **attrs)
    create(:reference_rent, year: 2025, district_id:, district_name: name, zone_id:,
                            min_per_sqm: ref - 5, ref_per_sqm: ref, max_per_sqm: ref + 5, **attrs)
  end

  before do
    # Zone 1: two districts sharing the same rents, like in the real dataset
    rent(27, "Ecole-Militaire", 1, 32.0)
    rent(28, "Gros-Caillou", 1, 32.0)
    rent(27, "Ecole-Militaire", 1, 28.0, rooms: 3)
    rent(28, "Gros-Caillou", 1, 28.0, rooms: 3)
    # Zone 14: one district
    rent(73, "Villette", 14, 22.0)
  end

  it "averages reference rents per zone and lists the zone's districts" do
    get "/api/v1/reports/zones"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq([
      {
        "zone_id" => 1, "districts_count" => 2, "district_names" => [ "Ecole-Militaire", "Gros-Caillou" ],
        "avg_min_per_sqm" => 25.0, "avg_ref_per_sqm" => 30.0, "avg_max_per_sqm" => 35.0
      },
      {
        "zone_id" => 14, "districts_count" => 1, "district_names" => [ "Villette" ],
        "avg_min_per_sqm" => 17.0, "avg_ref_per_sqm" => 22.0, "avg_max_per_sqm" => 27.0
      }
    ])
  end

  it "applies the same filters as the district report" do
    get "/api/v1/reports/zones", params: { rooms: 3 }

    expect(response.parsed_body["data"].map { it.values_at("zone_id", "avg_ref_per_sqm") }).to eq([ [ 1, 28.0 ] ])
  end

  it "rejects an unknown construction period" do
    get "/api/v1/reports/zones", params: { construction_period: "1900" }

    expect(response).to have_http_status(:bad_request)
  end
end
