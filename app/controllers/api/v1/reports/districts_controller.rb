module Api
  module V1
    module Reports
      class DistrictsController < BaseController
        def index
          render_report(report.by_district)
        end
      end
    end
  end
end
