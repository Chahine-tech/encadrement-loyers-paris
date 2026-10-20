require "rails_helper"

RSpec.describe ParisOpenData::Client do
  subject(:client) { described_class.new(page_size: 2, retry_interval: 0) }

  let(:records_url) { "#{described_class::BASE_URL}#{described_class::RECORDS_PATH}" }
  # Matches the records endpoint whatever the query string
  let(:any_records_request) { /\A#{Regexp.escape(records_url)}/ }

  def record(id_quartier:, piece: 1)
    {
      "annee" => "2025", "id_quartier" => id_quartier, "nom_quartier" => "Quartier #{id_quartier}",
      "id_zone" => 1, "piece" => piece, "epoque" => "Avant 1946", "meuble_txt" => "non meublé",
      "min" => 18.3, "ref" => 26.1, "max" => 31.3
    }
  end

  def json(body, status: 200)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json; charset=utf-8" } }
  end

  def stub_page(offset:, results:, total_count: 3)
    stub_request(:get, records_url)
      .with(query: hash_including("where" => 'annee="2025"', "limit" => "2", "offset" => offset.to_s))
      .to_return(json({ total_count:, results: }))
  end

  describe "#each_record" do
    it "follows pagination until total_count is reached" do
      first_page = stub_page(offset: 0, results: [ record(id_quartier: 1), record(id_quartier: 2) ])
      last_page = stub_page(offset: 2, results: [ record(id_quartier: 3) ])

      ids = client.each_record(year: 2025).map { it["id_quartier"] }

      expect(ids).to eq([ 1, 2, 3 ])
      expect(first_page).to have_been_requested.once
      expect(last_page).to have_been_requested.once
    end

    it "asks for a stable order so offset pages do not overlap" do
      stub = stub_request(:get, records_url)
        .with(query: hash_including("order_by" => described_class::STABLE_ORDER))
        .to_return(json({ total_count: 0, results: [] }))

      client.each_record(year: 2025).to_a

      expect(stub).to have_been_requested
    end

    it "retries transient server errors, then succeeds" do
      stub_request(:get, records_url)
        .with(query: hash_including("offset" => "0"))
        .to_return({ status: 503 }, json({ total_count: 1, results: [ record(id_quartier: 1) ] }))

      expect(client.each_record(year: 2025).count).to eq(1)
    end

    it "retries timeouts, then raises RequestFailed once retries are exhausted" do
      stub = stub_request(:get, any_records_request).to_timeout

      expect { client.each_record(year: 2025).to_a }.to raise_error(described_class::RequestFailed)
      expect(stub).to have_been_requested.times(4) # first attempt + 3 retries
    end

    it "does not retry client errors" do
      stub = stub_request(:get, any_records_request).to_return(status: 400, body: "bad request")

      expect { client.each_record(year: 2025).to_a }
        .to raise_error(described_class::RequestFailed, /HTTP 400/)
      expect(stub).to have_been_requested.once
    end

    it "raises UnexpectedResponse when a record lacks expected fields" do
      stub_page(offset: 0, results: [ record(id_quartier: 1).except("ref") ], total_count: 1)

      expect { client.each_record(year: 2025).to_a }
        .to raise_error(described_class::UnexpectedResponse, /missing fields: ref/)
    end

    it "raises UnexpectedResponse when the payload shape changes" do
      stub_request(:get, any_records_request).to_return(json({ records: [] }))

      expect { client.each_record(year: 2025).to_a }.to raise_error(described_class::UnexpectedResponse)
    end

    it "raises UnexpectedResponse when the body is not JSON" do
      stub_request(:get, any_records_request)
        .to_return(status: 200, body: "<html>maintenance</html>", headers: { "Content-Type" => "text/html" })

      expect { client.each_record(year: 2025).to_a }.to raise_error(described_class::UnexpectedResponse)
    end

    it "refuses a year that would not fit in the API pagination window" do
      stub_page(offset: 0, results: [], total_count: 10_001)

      expect { client.each_record(year: 2025).to_a }
        .to raise_error(described_class::UnexpectedResponse, /pagination window/)
    end
  end

  describe "#years" do
    it "returns the available years as sorted integers" do
      stub_request(:get, records_url)
        .with(query: hash_including("group_by" => "annee"))
        .to_return(json({ total_count: 2, results: [ { "annee" => "2025" }, { "annee" => "2019" } ] }))

      expect(client.years).to eq([ 2019, 2025 ])
    end
  end
end
