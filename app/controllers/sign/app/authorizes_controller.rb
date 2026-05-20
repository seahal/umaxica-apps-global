# typed: false
# frozen_string_literal: true

module Sign
  module App
    class AuthorizesController < PrivateController
      before_action :authenticate!

      def show
        access_claims = Actor.authentication.access_claims
        amr = access_claims&.dig("amr")
        result = ::Oidc::AuthorizeService.call(
          params: authorize_params,
          resource: current_client,
          auth_method: Array(amr).first,
          acr: access_claims&.dig("acr"),
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

      def sign_in_url_with_return(return_to)
        return super unless params[:screen_hint].to_s == "signup"

        new_sign_app_up_url(
          rt: return_to,
          ri: params[:ri].presence,
          host: sign_app_redirect_host,
          protocol: request.protocol,
        )
      end
    end
  end
end
