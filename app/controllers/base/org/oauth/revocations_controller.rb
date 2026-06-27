# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oauth
      class RevocationsController < Base::Org::BareController
        include BaseOauthEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers

        def create
          result = ::OidcTokenRevoker.call(
            token: params[:token],
            client_id: params[:client_id],
            client_secret: params[:client_secret],
            token_type_hint: params[:token_type_hint],
            host: request.host,
          )
          return head :ok if result.success?

          render json: { error: result.error, error_description: result.error_description },
                 status: :unauthorized
        end
      end
    end
  end
end
