require "rails_helper"

RSpec.describe ImportReferenceRentsJob do
  let(:importer) { instance_double(ParisOpenData::Importer) }

  before { allow(ParisOpenData::Importer).to receive(:new).and_return(importer) }

  it "is enqueued on the default queue with plain JSON arguments" do
    expect { described_class.perform_later([ 2025 ]) }
      .to have_enqueued_job(described_class).with([ 2025 ]).on_queue("default")
  end

  it "runs the importer for the given years" do
    allow(importer).to receive(:call)

    described_class.perform_now([ 2025 ])

    expect(importer).to have_received(:call).with(years: [ 2025 ])
  end

  it "re-enqueues itself when the API is temporarily unavailable" do
    allow(importer).to receive(:call).and_raise(ParisOpenData::Client::RequestFailed)

    expect { described_class.perform_now }.to have_enqueued_job(described_class)
  end

  it "is discarded, not retried, when the dataset format changed" do
    allow(importer).to receive(:call).and_raise(ParisOpenData::Client::UnexpectedResponse)

    expect { described_class.perform_now }.not_to have_enqueued_job(described_class)
  end

  it "disables Sidekiq's own retries so failures are not retried twice" do
    expect(described_class.get_sidekiq_options["retry"]).to be(false)
  end
end
