module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound do
        render_error :not_found, "not_found", "No reference rent matches these criteria"
      end

      rescue_from ActiveModel::ValidationError do |e|
        render_error :unprocessable_content, "validation_failed", "Invalid parameters",
                     details: e.model.errors.to_hash
      end

      rescue_from ActionController::BadRequest do |e|
        render_error :bad_request, "bad_request", e.message
      end

      private

      def render_error(status, code, message, details: nil)
        render status:, json: { error: code, message:, details: }.compact
      end

      def requested_year
        return ReferenceRent.current_year if params[:year].blank?

        Integer(params[:year], 10)
      rescue ArgumentError, TypeError
        raise ActionController::BadRequest, "year must be an integer"
      end
    end
  end
end
