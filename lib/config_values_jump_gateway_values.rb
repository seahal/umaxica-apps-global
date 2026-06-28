# frozen_string_literal: true

module ConfigValues
  JumpGatewayValues = Data.define(:origin, :jwks_uri, :audience, :ttl_seconds, :revoked_kids)
end

ConfigValuesJumpGatewayValues = ConfigValues::JumpGatewayValues

class << ConfigValues::JumpGatewayValues
  def build(env:, production:)
    public_origin = env.fetch("PUBLIC_JUMP_GATEWAY_URL", nil)
    legacy_origin = env.fetch("JUMP_GATEWAY_URL", nil)
    raw_origin =
      if production
        public_origin || legacy_origin || raise(KeyError, 'key not found: "PUBLIC_JUMP_GATEWAY_URL"')
      else
        public_origin || legacy_origin || "https://jump.umaxica.net"
      end

    origin = ConfigValues.build(raw_origin, allow_localhost: !production)
    jwks_uri =
      begin
        raw = env.fetch("PUBLIC_JUMP_GATEWAY_JWKS_URL", nil) || env.fetch("JUMP_GATEWAY_JWKS_URL", nil)
        raw.present? ? ConfigValues.build(raw, allow_localhost: !production).to_s : "#{origin}/.well-known/jwks.json"
      rescue KeyError
        "#{origin}/.well-known/jwks.json"
      end
    ttl_seconds = env.fetch("JUMP_RT_TTL_SECONDS", 5.minutes.to_i).to_i
    audience = env.fetch("PUBLIC_JUMP_GATEWAY_AUDIENCE", nil) || env.fetch("JUMP_GATEWAY_AUDIENCE", nil) || origin.to_s
    revoked_kids =
      env.fetch("JUMP_RETURN_REVOKED_KIDS", "").to_s.split(",").each_with_object([]) do |kid, memo|
        stripped = kid.strip
        memo << stripped unless stripped.empty?
      end.freeze
    ConfigValues::JumpGatewayValues.new(origin, jwks_uri, audience, ttl_seconds, revoked_kids).freeze
  end
end
