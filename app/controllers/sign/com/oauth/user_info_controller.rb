# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Oauth
      class UserInfoController < BaseController
        AUTHENTICATION_MODE = :open

        def show
          result = Oidc::AccessTokenAuthenticator.call(
            access_token: bearer_token,
            resource_type: "visitor",
            host: request.host,
          )
          return render json: { error: result.error }, status: :unauthorized unless result.success?

          render json: Oidc::UserInfoResponse.build(resource: result.resource, payload: result.payload)
        end

        private

        def bearer_token
          request.authorization.to_s.delete_prefix("Bearer ").presence
        end
      end
    end
  end
end
