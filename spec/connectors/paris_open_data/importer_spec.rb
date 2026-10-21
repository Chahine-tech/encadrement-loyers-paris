require "rails_helper"

RSpec.describe ParisOpenData::Importer do
  subject(:importer) { described_class.new(client:) }

  let(:client) { instance_double(ParisOpenData::Client, years: [ 2025 ]) }

  def api_record(**overrides)
    {
      "annee" => "2025", "id_quartier" => 67, "nom_quartier" => "Batignolles", "id_zone" => 10,
      "piece" => 2, "epoque" => "Apres 1990", "meuble_txt" => "meublé",
      "min" => 18.3, "ref" => 26.1, "max" => 31.3
    }.merge(overrides)
  end

  def stub_records(*records, year: 2025)
    allow(client).to receive(:each_record).with(year:).and_return(records.each)
  end

  it "maps API fields to a reference rent" do
    stub_records(api_record)

    importer.call

    expect(ReferenceRent.sole).to have_attributes(
      year: 2025, district_id: 67, district_name: "Batignolles", zone_id: 10, rooms: 2,
      construction_period: "after_1990", furnished: true,
      min_per_sqm: BigDecimal("18.3"), ref_per_sqm: BigDecimal("26.1"), max_per_sqm: BigDecimal("31.3")
    )
  end

  it "maps every known construction period and furnished label" do
    records = described_class::CONSTRUCTION_PERIODS.keys.product(described_class::FURNISHED.keys)
      .map { |epoque, meuble| api_record("epoque" => epoque, "meuble_txt" => meuble) }
    stub_records(*records)

    expect { importer.call }.to change(ReferenceRent, :count).by(8)
  end

  it "is idempotent: a second run updates rows instead of duplicating them" do
    stub_records(api_record, api_record("piece" => 3))
    importer.call

    stub_records(api_record("ref" => 27.0), api_record("piece" => 3))

    expect { importer.call }.not_to change(ReferenceRent, :count)
    expect(ReferenceRent.find_by!(rooms: 2).ref_per_sqm).to eq(BigDecimal("27.0"))
  end

  it "imports every available year when none is given" do
    allow(client).to receive(:years).and_return([ 2024, 2025 ])
    stub_records(api_record("annee" => "2024"), year: 2024)
    stub_records(api_record, year: 2025)

    importer.call

    expect(ReferenceRent.distinct.pluck(:year)).to contain_exactly(2024, 2025)
  end

  it "records a successful run" do
    stub_records(api_record, api_record("piece" => 3))

    run = importer.call

    expect(run).to have_attributes(status: "succeeded", years: [ 2025 ], records_count: 2)
    expect(run.finished_at).to be_present
  end

  context "when a record has an unknown value" do
    before { stub_records(api_record("epoque" => "Apres 2030")) }

    it "raises InvalidRecord with the offending value" do
      expect { importer.call }.to raise_error(described_class::InvalidRecord, /Apres 2030/)
    end

    it "records the failed run" do
      expect { importer.call }.to raise_error(described_class::InvalidRecord)

      expect(ImportRun.sole).to have_attributes(
        status: "failed", error_class: "ParisOpenData::Importer::InvalidRecord", records_count: 0
      )
    end
  end

  it "records the run as failed when the API is down, then re-raises" do
    allow(client).to receive(:years).and_raise(ParisOpenData::Client::RequestFailed, "HTTP 503")

    expect { importer.call }.to raise_error(ParisOpenData::Client::RequestFailed)
    expect(ImportRun.sole).to have_attributes(status: "failed", error_message: "HTTP 503")
  end

  it "re-raises the original error even if the failure cannot be recorded" do
    allow(client).to receive(:years).and_raise(ParisOpenData::Client::RequestFailed, "HTTP 503")
    allow_any_instance_of(ImportRun).to receive(:fail!).and_raise(ActiveRecord::ConnectionNotEstablished)

    expect { importer.call }.to raise_error(ParisOpenData::Client::RequestFailed, "HTTP 503")
  end
end
