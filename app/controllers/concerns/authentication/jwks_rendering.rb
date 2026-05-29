# typed: false
# frozen_string_literal: true

module Authentication
  module JwksRendering
    extend ActiveSupport::Concern

    def show
      expires_in(1.hour, public: true)
      render json: ::Jit::Security::Jwt::JwksService.jwk_set(self.class::JWT_KEY_NAMESPACE)
    end

    private

    def skip_jwks_session!
      request.session_options[:skip] = true
    end
  end
end
