require "rails_helper"

RSpec.describe "GET /api/v1/reports/districts", type: :request do
  def rent(district_id, name, ref, **attrs)
    create(:reference_rent, year: 2025, district_id:, district_name: name,
                            min_per_sqm: ref - 5, ref_per_sqm: ref, max_per_sqm: ref + 5, **attrs)
  end

  before do
    rent(1, "Arsenal", 30.0, rooms: 1)
    rent(1, "Arsenal", 26.0, rooms: 2)
    rent(2, "Belleville", 24.0, rooms: 1)
    rent(2, "Belleville", 22.0, rooms: 2, furnished: true)
    rent(3, "Old year", 99.0, year: 2024)
  end

  it "averages reference rents per district, most expensive first" do
    get "/api/v1/reports/districts"

    expect(response).to have_http_status(:ok)
    rows = response.parsed_body["data"]
    expect(rows.map { it.values_at("district_name", "avg_ref_per_sqm") })
      .to eq([ [ "Arsenal", 28.0 ], [ "Belleville", 23.0 ] ])
    expect(rows.first).to include("avg_min_per_sqm" => 23.0, "avg_max_per_sqm" => 33.0)
  end

  it "filters by profile" do
    get "/api/v1/reports/districts", params: { rooms: 1, furnished: false }

    rows = response.parsed_body["data"]
    expect(rows.map { it.values_at("district_name", "avg_ref_per_sqm") })
      .to eq([ [ "Arsenal", 30.0 ], [ "Belleville", 24.0 ] ])
    expect(response.parsed_body["meta"]).to eq("year" => 2025, "filters" => { "rooms" => "1", "furnished" => "false" })
  end

  it "rejects an unknown construction period instead of returning an empty report" do
    get "/api/v1/reports/districts", params: { construction_period: "1900" }

    expect(response).to have_http_status(:bad_request)
  end

  it "runs a single SQL query for the whole report (no N+1)" do
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get "/api/v1/reports/districts", params: { year: 2025 }
    end

    expect(queries.count { it.include?("GROUP BY") }).to eq(1)
    expect(queries.size).to eq(1)
  end
end
