module ParisOpenData
  # Idempotent: rows are upserted on their natural key, so a rerun never duplicates them.
  class Importer
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

    def call(years: nil)
      run = ImportRun.create!(started_at: Time.current)
      count = 0

      years ||= @client.years
      run.update!(years:)

      # No transaction: it would hold a connection open during HTTP calls, and a rerun is safe.
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
        construction_period: lookup(CONSTRUCTION_PERIODS, record, "epoque"),
        furnished: lookup(FURNISHED, record, "meuble_txt"),
        # BigDecimal(26.1) would keep the float's binary noise
        min_per_sqm: BigDecimal(record["min"].to_s),
        ref_per_sqm: BigDecimal(record["ref"].to_s),
        max_per_sqm: BigDecimal(record["max"].to_s)
      }
    rescue ArgumentError, TypeError => e
      raise InvalidRecord, "cannot map record #{record.inspect}: #{e.message}"
    end

    def lookup(mapping, record, field)
      mapping.fetch(record[field]) do
        raise InvalidRecord, "unknown #{field} #{record[field].inspect} (known: #{mapping.keys.join(', ')})"
      end
    end
  end
end
