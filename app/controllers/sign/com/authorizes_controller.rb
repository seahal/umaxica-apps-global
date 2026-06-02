# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class AuthorizesController < Sign::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      before_action :authenticate!

      def show
        result = ::Oidc::AuthorizeService.call(
          params: authorize_params,
          resource: current_visitor,
        )

        if result.success?
          redirect_to_jump_url(result.redirect_url)
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

      def sign_in_url_with_pt(return_to)
        return super unless params[:screen_hint].to_s == "signup"

        _ = return_to
        new_sign_com_sign_up_url(
          ri: params[:ri].presence,
          host: sign_com_redirect_host,
          protocol: "https",
        )
      end
    end
  end
end
