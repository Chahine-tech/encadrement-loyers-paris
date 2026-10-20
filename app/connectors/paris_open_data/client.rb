module ParisOpenData
  # HTTP client for the "Logement - Encadrement des loyers" dataset (Opendatasoft Explore API v2.1).
  #
  # Only talks HTTP: pagination, timeouts, retries and error translation.
  # It returns raw API records; mapping them to our schema is the importer's job.
  class Client
    class Error < StandardError; end
    # Network failure or HTTP error status, after retries are exhausted
    class RequestFailed < Error; end
    # The API answered, but not in the shape we rely on (dataset or API changed)
    class UnexpectedResponse < Error; end

    BASE_URL = "https://opendata.paris.fr".freeze
    RECORDS_PATH = "/api/explore/v2.1/catalog/datasets/logement-encadrement-des-loyers/records".freeze
    FIELDS = %w[annee id_quartier nom_quartier id_zone piece epoque meuble_txt min ref max].freeze

    # The API rejects offset + limit > 10_000 (InvalidRESTParameterError),
    # so we paginate year by year (~2_560 records each) instead of over the whole dataset.
    MAX_WINDOW = 10_000
    MAX_PAGE_SIZE = 100

    # Offset pagination needs a deterministic order, otherwise pages can overlap or skip rows.
    STABLE_ORDER = "id_quartier,piece,epoque,meuble_txt".freeze

    RETRIABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    def initialize(page_size: MAX_PAGE_SIZE, max_retries: 3, retry_interval: 0.5, connection: nil)
      raise ArgumentError, "page_size must be between 1 and #{MAX_PAGE_SIZE}" unless page_size.between?(1, MAX_PAGE_SIZE)

      @page_size = page_size
      @connection = connection || build_connection(max_retries:, retry_interval:)
    end

    # Years available in the dataset, e.g. [2019, 2020, ..., 2025]
    def years
      body = get(select: "annee", group_by: "annee", limit: MAX_PAGE_SIZE)
      body.fetch("results").map { |row| Integer(row.fetch("annee")) }.sort
    rescue KeyError, ArgumentError, TypeError => e
      raise UnexpectedResponse, "cannot read years: #{e.message}"
    end

    # Yields every record of a given year, one page at a time under the hood.
    # Returns an Enumerator when called without a block, so callers can use each_slice, map...
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
        # Outermost: retries transient failures (timeouts, 429, 5xx) with exponential backoff and jitter.
        # Never retries 4xx like 400: sending the same bad request again cannot succeed.
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
        # Turns 4xx/5xx into Faraday exceptions (Faraday::ClientError, Faraday::ServerError...)
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
