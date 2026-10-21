module ParisOpenData
  # Opendatasoft Explore API v2.1 client for the "Logement - Encadrement des loyers" dataset.
  class Client
    class Error < StandardError; end
    class RequestFailed < Error; end
    class UnexpectedResponse < Error; end

    BASE_URL = "https://opendata.paris.fr".freeze
    RECORDS_PATH = "/api/explore/v2.1/catalog/datasets/logement-encadrement-des-loyers/records".freeze
    FIELDS = %w[annee id_quartier nom_quartier id_zone piece epoque meuble_txt min ref max].freeze

    # The API rejects offset + limit > 10_000, hence one pagination per year (~2_560 records).
    MAX_WINDOW = 10_000
    MAX_PAGE_SIZE = 100

    # Without a deterministic order, offset pages can overlap or skip rows.
    STABLE_ORDER = "id_quartier,piece,epoque,meuble_txt".freeze

    RETRIABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    def initialize(page_size: MAX_PAGE_SIZE, max_retries: 3, retry_interval: 0.5, connection: nil)
      raise ArgumentError, "page_size must be between 1 and #{MAX_PAGE_SIZE}" unless page_size.between?(1, MAX_PAGE_SIZE)

      @page_size = page_size
      @connection = connection || build_connection(max_retries:, retry_interval:)
    end

    def years
      body = get(select: "annee", group_by: "annee", limit: MAX_PAGE_SIZE)
      body.fetch("results").map { |row| Integer(row.fetch("annee")) }.sort
    rescue KeyError, ArgumentError, TypeError => e
      raise UnexpectedResponse, "cannot read years: #{e.message}"
    end

    def each_record(year:, &block)
      return enum_for(:each_record, year:) unless block

      offset = 0
      loop do
        body = get(
          select: FIELDS.join(","),
          where: %(annee="#{Integer(year)}"),
          order_by: STABLE_ORDER,
          limit: @page_size,
          offset:
        )
        total = body.fetch("total_count")
        if total > MAX_WINDOW
          raise UnexpectedResponse, "year #{year} has #{total} records, above the #{MAX_WINDOW} pagination window"
        end

        records = body.fetch("results")
        records.each { |record| yield validate_record!(record) }

        offset += records.size
        break if records.empty? || offset >= total
      end
    end

    private

    def build_connection(max_retries:, retry_interval:)
      Faraday.new(url: BASE_URL, request: { open_timeout: 5, timeout: 15 }) do |f|
        f.request :retry,
                  max: max_retries,
                  interval: retry_interval,
                  backoff_factor: 2,
                  interval_randomness: 0.5,
                  methods: %i[get],
                  retry_statuses: RETRIABLE_STATUSES,
                  exceptions: [
                    Faraday::ConnectionFailed, Faraday::TimeoutError,
                    Faraday::ServerError, Faraday::TooManyRequestsError
                  ]
        f.response :raise_error
        f.response :json, content_type: /\bjson$/
      end
    end

    def get(params)
      body = @connection.get(RECORDS_PATH, params).body
      unless body.is_a?(Hash) && body["total_count"].is_a?(Integer) && body["results"].is_a?(Array)
        raise UnexpectedResponse, "expected a JSON object with total_count and results, got: #{body.to_s.truncate(200)}"
      end

      body
    rescue Faraday::ParsingError => e
      raise UnexpectedResponse, "invalid JSON: #{e.message}"
    rescue Faraday::Error => e
      status = e.response_status ? "HTTP #{e.response_status}" : e.class.name
      raise RequestFailed, "Paris open data request failed (#{status}): #{e.message}"
    end

    def validate_record!(record)
      missing = FIELDS - record.keys
      raise UnexpectedResponse, "record is missing fields: #{missing.join(', ')}" if missing.any?

      record
    end
  end
end
