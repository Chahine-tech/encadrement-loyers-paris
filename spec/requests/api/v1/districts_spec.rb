require "rails_helper"

RSpec.describe "GET /api/v1/districts", type: :request do
  before do
    # Same district in several profiles: it must be listed once
    create(:reference_rent, year: 2025, district_id: 67, district_name: "Batignolles", zone_id: 10, rooms: 1)
    create(:reference_rent, year: 2025, district_id: 67, district_name: "Batignolles", zone_id: 10, rooms: 2)
    create(:reference_rent, year: 2025, district_id: 1, district_name: "Arsenal", zone_id: 2)
    create(:reference_rent, year: 2024, district_id: 99, district_name: "Only in 2024", zone_id: 3)
  end

  it "lists each district of the latest year once, sorted by name" do
    get "/api/v1/districts"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to eq([
      { "id" => 1, "name" => "Arsenal", "zone_id" => 2 },
      { "id" => 67, "name" => "Batignolles", "zone_id" => 10 }
    ])
  end

  it "exposes the form options in meta" do
    get "/api/v1/districts"

    expect(response.parsed_body["meta"]).to eq(
      "year" => 2025,
      "years" => [ 2024, 2025 ],
      "construction_periods" => %w[before_1946 from_1946_to_1970 from_1971_to_1990 after_1990]
    )
  end

  it "accepts a year" do
    get "/api/v1/districts", params: { year: 2024 }

    expect(response.parsed_body["data"].pluck("name")).to eq([ "Only in 2024" ])
  end

  it "rejects a non-numeric year" do
    get "/api/v1/districts", params: { year: "last" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to include("error" => "bad_request")
  end

  it "rejects a year sent as an array" do
    get "/api/v1/districts?year[]=2024"

    expect(response).to have_http_status(:bad_request)
  end
end
