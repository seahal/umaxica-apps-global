# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class JwksController < BareController
      AUTHENTICATION_MODE = :bare

      def show
        expires_in(1.hour, public: true)
        render json: ::Oidc::JwksService.jwk_set
      end
    end
  end
end
