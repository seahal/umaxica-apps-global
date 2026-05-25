# typed: false
# frozen_string_literal: true

module Sign
  module EdgeV0JsonApi
    extend ActiveSupport::Concern

    private

    def authenticate!
      return if logged_in?

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def ensure_json_request
      request.format = :json
    end
  end
end
