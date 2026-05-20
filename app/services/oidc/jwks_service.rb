# typed: false
# frozen_string_literal: true

require "jwt"

module Oidc
  class JwksService
    class << self
      def jwk_set
        kid = Jit::Security::Jwt::Keyring.active_kid
        public_key = Jit::Security::Jwt::Keyring.public_key_for(kid)
        return { keys: [] } unless public_key

        jwk = JWT::JWK.new(public_key, kid: kid)
        exported = jwk.export
        exported[:use] = "sig"
        exported[:alg] = Authentication::TokenService::JWT_ALGORITHM

        { keys: [exported] }
      end
    end
  end
end
