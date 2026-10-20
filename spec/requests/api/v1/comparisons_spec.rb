require "rails_helper"

RSpec.describe "GET /api/v1/comparisons", type: :request do
  before do
    create(:reference_rent,
           year: 2025, district_id: 67, district_name: "Batignolles", zone_id: 10, rooms: 2,
           construction_period: :before_1946, furnished: false,
           min_per_sqm: 19.0, ref_per_sqm: 27.1, max_per_sqm: 32.5)
  end

  let(:params) do
    { district_id: 67, rooms: 2, construction_period: "before_1946", furnished: false, surface: 30, rent: 1100 }
  end

  it "returns the comparison" do
    get "/api/v1/comparisons", params: params

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"]).to include(
      "status" => "above_max",
      "year" => 2025,
      "district" => { "id" => 67, "name" => "Batignolles", "zone_id" => 10 },
      "rent" => 1100.0,
      "legal_rents" => { "min" => 570.0, "ref" => 813.0, "max" => 975.0 },
      "per_sqm" => { "min" => 19.0, "ref" => 27.1, "max" => 32.5 },
      "excess" => 125.0
    )
  end

  it "returns 422 with every invalid field" do
    get "/api/v1/comparisons", params: params.merge(surface: -1, rent: "")

    expect(response).to have_http_status(:unprocessable_content)
    body = response.parsed_body
    expect(body["error"]).to eq("validation_failed")
    expect(body["details"].keys).to contain_exactly("surface", "rent")
  end

  it "returns 404 when no reference matches" do
    get "/api/v1/comparisons", params: params.merge(district_id: 999)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body["error"]).to eq("not_found")
  end

  it "ignores unknown parameters" do
    get "/api/v1/comparisons", params: params.merge(admin: true)

    expect(response).to have_http_status(:ok)
  end
end
