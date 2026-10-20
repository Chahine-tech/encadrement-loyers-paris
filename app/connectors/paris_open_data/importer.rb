module ParisOpenData
  # Maps Paris open data records to ReferenceRent rows and upserts them.
  #
  # Idempotent: rows are keyed by the natural key (year, district, rooms, period, furnished),
  # so running the import twice updates the same rows instead of duplicating them.
  # That is what makes Sidekiq retries safe, even after a partial failure.
  class Importer
    # A record whose values we do not know how to map (e.g. a new construction period label)
    class InvalidRecord < Client::Error; end

    BATCH_SIZE = 500

    CONSTRUCTION_PERIODS = {
      "Avant 1946" => :before_1946,
      "1946-1970" => :from_1946_to_1970,
      "1971-1990" => :from_1971_to_1990,
      "Apres 1990" => :after_1990
    }.freeze

    FURNISHED = { "meublé" => true, "non meublé" => false }.freeze

    def initialize(client: Client.new)
      @client = client
    end

    # Imports the given years, or every year available in the dataset.
    # Returns the ImportRun; re-raises on failure after recording it.
    def call(years: nil)
      run = ImportRun.create!(started_at: Time.current)
      count = 0

      years ||= @client.years
      run.update!(years:)

      # No wrapping transaction on purpose: it would hold a DB connection open during
      # HTTP calls. A failure leaves earlier batches imported, and a rerun completes them.
      years.each do |year|
        @client.each_record(year:).each_slice(BATCH_SIZE) do |records|
          rows = records.map { to_row(it) }
          ReferenceRent.upsert_all(rows, unique_by: :idx_reference_rents_natural_key)
          count += rows.size
        end
      end

      run.succeed!(records_count: count)
      run
    rescue StandardError => e
      run&.fail!(e, records_count: count)
      raise
    end

    private

    def to_row(record)
      {
        year: Integer(record["annee"]),
        district_id: record["id_quartier"],
        district_name: record["nom_quartier"],
        zone_id: record["id_zone"],
        rooms: record["piece"],
        construction_period: map(CONSTRUCTION_PERIODS, record, "epoque"),
        furnished: map(FURNISHED, record, "meuble_txt"),
        # Through a string: BigDecimal(26.1) would carry the float's binary noise
        min_per_sqm: BigDecimal(record["min"].to_s),
        ref_per_sqm: BigDecimal(record["ref"].to_s),
        max_per_sqm: BigDecimal(record["max"].to_s)
      }
    rescue ArgumentError, TypeError => e
      raise InvalidRecord, "cannot map record #{record.inspect}: #{e.message}"
    end

    def map(mapping, record, field)
      mapping.fetch(record[field]) do
        raise InvalidRecord, "unknown #{field} #{record[field].inspect} (known: #{mapping.keys.join(', ')})"
      end
    end
  end
end
