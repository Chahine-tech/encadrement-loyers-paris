module Api
  module V1
    module Reports
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

        # Otherwise an unknown value silently matches nothing
        def validate_construction_period!(value)
          return if value.blank? || ReferenceRent.construction_periods.key?(value)

          raise ActionController::BadRequest, "unknown construction_period #{value.inspect}"
        end
      end
    end
  end
end
