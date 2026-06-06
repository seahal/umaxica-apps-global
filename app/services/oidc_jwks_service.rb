# typed: false
# frozen_string_literal: true

require "jwt"
require "jit_security_jwt_jwks_service"

class OidcJwksService
  class << self
    delegate :jwk_set, to: :"JitSecurityJwtJwksService"
  end
end
