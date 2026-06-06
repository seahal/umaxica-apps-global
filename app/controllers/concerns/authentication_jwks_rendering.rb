# typed: false
# frozen_string_literal: true

module AuthenticationJwksRendering
  extend ActiveSupport::Concern

  def show
    expires_in(1.hour, public: true)
    render json: ::JitSecurityJwtJwksService.jwk_set(self.class::JWT_KEY_NAMESPACE)
  end

  private

  def skip_jwks_session!
    request.session_options[:skip] = true
  end
end
