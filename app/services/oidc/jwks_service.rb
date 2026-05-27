# typed: false
# frozen_string_literal: true

require "jwt"
require "jit/security/jwt/jwks_service"

module Oidc
  class JwksService
    class << self
      delegate :jwk_set, to: :"Jit::Security::Jwt::JwksService"
    end
  end
end
