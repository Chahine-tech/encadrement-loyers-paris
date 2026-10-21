class ImportReferenceRentsJob < ApplicationJob
  queue_as :default

  # Active Job owns retries; otherwise Sidekiq retries again once retry_on gives up.
  sidekiq_options retry: false

  retry_on ParisOpenData::Client::RequestFailed, wait: :polynomially_longer, attempts: 5

  discard_on ParisOpenData::Client::UnexpectedResponse, ParisOpenData::Importer::InvalidRecord

  def perform(years = nil)
    ParisOpenData::Importer.new.call(years:)
  end
end
