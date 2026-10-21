module Api
  module V1
    class DistrictsController < BaseController
      def index
        year = requested_year
        districts = ReferenceRent.where(year:)
                                 .distinct
                                 .order(:district_name)
                                 .pluck(:district_id, :district_name, :zone_id)
                                 .map { |id, name, zone_id| { id:, name:, zone_id: } }

        render json: {
          data: districts,
          meta: {
            year:,
            years: ReferenceRent.distinct.order(:year).pluck(:year),
            construction_periods: ReferenceRent.construction_periods.keys
          }
        }
      end
    end
  end
end
