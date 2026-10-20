class ImportRun < ApplicationRecord
  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, validate: true

  validates :started_at, presence: true

  def succeed!(records_count:)
    update!(status: :succeeded, records_count:, finished_at: Time.current)
  end

  def fail!(error, records_count:)
    update!(
      status: :failed,
      records_count:,
      error_class: error.class.name,
      error_message: error.message.truncate(1_000),
      finished_at: Time.current
    )
  end
end
