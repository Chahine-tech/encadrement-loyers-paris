module Api
  module V1
    module Reports
      # GET /api/v1/reports/zones?year=2025&rooms=2&furnished=false&construction_period=before_1946
      # Rents are set per zone: this is the report to chart.
      class ZonesController < BaseController
        def index
          render_report(:zone)
        end
      end
    end
  end
end
