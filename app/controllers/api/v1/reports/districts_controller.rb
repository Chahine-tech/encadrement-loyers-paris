module Api
  module V1
    module Reports
      class DistrictsController < BaseController
        def index
          render_report(:district)
        end
      end
    end
  end
end
