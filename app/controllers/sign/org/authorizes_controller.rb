# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class AuthorizesController < ApplicationController
      auth_required!
      before_action :authenticate!

      def show
        result = Oidc::AuthorizeService.call(
          params: authorize_params,
          resource: current_operator,
        )

        if result.success?
          redirect_to(result.redirect_url, allow_other_host: true)
        else
          render json: { error: result.error, error_description: result.error_description },
                 status: :bad_request
        end
      end

      private

      def authorize_params
        params.permit(
          :response_type, :client_id, :redirect_uri, :state,
          :code_challenge, :code_challenge_method, :scope, :nonce,
        )
      end
    end
  end
end
