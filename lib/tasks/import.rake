namespace :import do
  desc "Enqueue the import of Paris reference rents (every year, or YEARS=2024,2025)"
  task reference_rents: :environment do
    years = ENV["YEARS"]&.split(",")&.map { Integer(it) }
    ImportReferenceRentsJob.perform_later(years)

    puts "Import enqueued for #{years&.join(', ') || 'every year'}. Follow it with: docker compose logs -f sidekiq"
  end
end
