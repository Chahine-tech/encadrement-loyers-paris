module Api
  module V1
    class ComparisonsController < BaseController
      def show
        result = RentComparison.new(comparison_params).call

        render json: { data: RentComparisonSerializer.new(result).as_json }
      end

      private

      def comparison_params
        params.permit(:district_id, :rooms, :construction_period, :furnished, :surface, :rent, :year)
      end
    end
  end
end
