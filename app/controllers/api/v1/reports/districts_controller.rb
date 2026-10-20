module Api
  module V1
    module Reports
      # GET /api/v1/reports/districts?year=2025&rooms=2&furnished=false&construction_period=before_1946
      class DistrictsController < BaseController
        def index
          filters = params.permit(*DistrictRentReport::FILTERS)
          validate_construction_period!(filters[:construction_period])
          year = requested_year

          render json: {
            data: DistrictRentReport.new(year:, filters:).rows,
            meta: { year:, filters: filters.to_h.compact_blank }
          }
        end

        private

        # An unknown enum value would silently match nothing: reject it explicitly instead
        def validate_construction_period!(value)
          return if value.blank? || ReferenceRent.construction_periods.key?(value)

          raise ActionController::BadRequest, "unknown construction_period #{value.inspect}"
        end
      end
    end
  end
end
