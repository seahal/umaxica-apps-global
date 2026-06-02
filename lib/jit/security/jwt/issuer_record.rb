# typed: false
# frozen_string_literal: true

module Jit
  module Security
    module Jwt
      KeyRecord = Data.define(:kid, :private_key, :public_key, :public_jwk, :state)

      VERIFY_STATES = %w(active grace).freeze
      PUBLISH_STATES = %w(active grace).freeze

      IssuerRecord =
        Data.define(:id, :namespace, :issuer, :audiences, :current_kid, :keys, :revoked_kids) do
          def current_key = keys.fetch(current_kid, nil)

          def public_key_for(kid)
            key = keys.fetch(kid.to_s, nil)
            return nil unless key
            return nil if revoked_kids.include?(kid.to_s)
            return nil unless VERIFY_STATES.include?(key.state)

            key.public_key
          end

          def jwks
            {
              keys: keys.values.filter_map do |key|
                next unless PUBLISH_STATES.include?(key.state)

                key.public_jwk
              end,
            }
          end
        end
    end
  end
end
