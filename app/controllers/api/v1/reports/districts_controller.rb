module Api
  module V1
    module Reports
      # GET /api/v1/reports/districts?year=2025&rooms=2&furnished=false&construction_period=before_1946
      class DistrictsController < BaseController
        def index
          render_report(:district)
        end
      end
    end
  end
end
