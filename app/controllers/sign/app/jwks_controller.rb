# typed: false
# frozen_string_literal: true

module Sign
  module App
    class JwksController < BareController
      def show
        expires_in(1.hour, public: true)
        render json: ::Oidc::JwksService.jwk_set
      end
    end
  end
end
