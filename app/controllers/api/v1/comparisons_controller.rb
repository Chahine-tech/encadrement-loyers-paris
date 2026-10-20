module Api
  module V1
    class ComparisonsController < BaseController
      # GET /api/v1/comparisons?district_id=67&rooms=2&construction_period=before_1946&furnished=false&surface=30&rent=1100
      def show
        result = RentComparison.new(comparison_params).call

        render json: { data: RentComparisonSerializer.new(result).as_json }
      end

      private

      # Strong parameters: only these keys reach the service, anything else is dropped
      def comparison_params
        params.permit(:district_id, :rooms, :construction_period, :furnished, :surface, :rent, :year)
      end
    end
  end
end
