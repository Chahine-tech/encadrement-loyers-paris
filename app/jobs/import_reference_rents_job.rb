class ImportReferenceRentsJob < ApplicationJob
  queue_as :default

  # Retries are handled by Active Job below. Without this, once retry_on gives up,
  # Sidekiq would retry the job again on its own (up to 25 times by default).
  sidekiq_options retry: false

  # Transient network or API outage: try again later, with growing delays.
  retry_on ParisOpenData::Client::RequestFailed, wait: :polynomially_longer, attempts: 5

  # The dataset changed shape: retrying cannot help, a human must update the mapping.
  # The failure is still recorded in ImportRun.
  discard_on ParisOpenData::Client::UnexpectedResponse, ParisOpenData::Importer::InvalidRecord

  # Arguments must be simple JSON types: pass years, never ActiveRecord objects.
  def perform(years = nil)
    ParisOpenData::Importer.new.call(years:)
  end
end
