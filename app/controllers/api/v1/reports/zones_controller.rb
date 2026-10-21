module Api
  module V1
    module Reports
      class ZonesController < BaseController
        def index
          render_report(report.by_zone)
        end
      end
    end
  end
end
