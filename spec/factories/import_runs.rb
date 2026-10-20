FactoryBot.define do
  factory :import_run do
    started_at { Time.current }
  end
end
