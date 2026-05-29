# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"
require "json"
require "jit/security/jwt/registry"

module Jit
  module Security
    module Jwt
      module Keyring
        module_function

        def active_kid(issuer_id = "auth")
          Registry.issuer(issuer_id).current_kid ||
            raise(Registry::ConfigurationError, "#{issuer_id} active kid is not configured")
        end

        def private_key_for_active(issuer_id = "auth")
          private_key_for(active_kid(issuer_id), issuer_id: issuer_id)
        end

        def public_key_for_active(issuer_id = "auth")
          public_key_for(active_kid(issuer_id), issuer_id: issuer_id)
        end

        def private_key_for(kid, issuer_id: "auth")
          Registry.private_key_for(issuer_id, kid)
        end

        def public_key_for(kid, issuer_id: "auth")
          Registry.public_key_for(issuer_id, kid)
        end

        def encode(payload, issuer_id: "auth")
          kid = active_kid(issuer_id)
          pk = private_key_for(kid, issuer_id: issuer_id)
          raise Registry::ConfigurationError, "Missing private key for kid: #{kid}" if pk.nil?

          JWT.encode(payload, pk, "ES384", { kid: kid, typ: payload["typ"] })
        end

        def parse_header(token)
          Registry.parse_header(token)
        end

        def parse_keyset(raw)
          return {} if raw.blank?

          parsed = JSON.parse(raw)
          return parsed if parsed.is_a?(Hash)

          {}
        rescue JSON::ParserError
          {}
        end

        def decode_key(base64_der)
          return nil if base64_der.blank?

          OpenSSL::PKey::EC.new(Base64.decode64(base64_der))
        rescue OpenSSL::PKey::PKeyError
          nil
        end
      end
    end
  end
end
