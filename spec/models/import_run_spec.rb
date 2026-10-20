require "rails_helper"

RSpec.describe ImportRun do
  it "starts as running" do
    expect(create(:import_run)).to be_running
  end

  it "records a failure with the error details" do
    run = create(:import_run)

    run.fail!(RuntimeError.new("boom"), records_count: 3)

    expect(run).to have_attributes(status: "failed", error_class: "RuntimeError", error_message: "boom", records_count: 3)
    expect(run.finished_at).to be_present
  end
end
