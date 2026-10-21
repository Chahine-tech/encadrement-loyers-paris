module Api
  module V1
    module Reports
      class BaseController < Api::V1::BaseController
        private

        def report
          @report ||= RentReport.new(
            year: requested_year,
            **params.permit(*RentReport::FILTERS).to_h.symbolize_keys.compact_blank
          )
        end

        def render_report(rows)
          render json: { data: rows, meta: { year: report.year, filters: report.filters } }
        end
      end
    end
  end
end
