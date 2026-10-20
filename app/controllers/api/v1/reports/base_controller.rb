module Api
  module V1
    module Reports
      # Shared by every report: same filters, same response shape
      class BaseController < Api::V1::BaseController
        private

        def render_report(by)
          filters = params.permit(*RentReport::FILTERS)
          validate_construction_period!(filters[:construction_period])
          year = requested_year

          render json: {
            data: RentReport.new(by:, year:, filters:).rows,
            meta: { year:, filters: filters.to_h.compact_blank }
          }
        end

        # An unknown enum value would silently match nothing: reject it explicitly instead
        def validate_construction_period!(value)
          return if value.blank? || ReferenceRent.construction_periods.key?(value)

          raise ActionController::BadRequest, "unknown construction_period #{value.inspect}"
        end
      end
    end
  end
end
