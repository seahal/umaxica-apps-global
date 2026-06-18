# frozen_string_literal: true

module ConfigValues
  JumpGatewayValues = Data.define(:origin, :jwks_uri, :audience, :ttl_seconds, :revoked_kids)
end

ConfigValuesJumpGatewayValues = ConfigValues::JumpGatewayValues

class << ConfigValues::JumpGatewayValues
  def build(env:, production:)
    origin = ConfigValues.build(
      production ? env.fetch("JUMP_GATEWAY_URL") : env.fetch("JUMP_GATEWAY_URL", "https://jump.umaxica.net"),
      allow_localhost: !production,
    )
    jwks_uri =
      begin
        raw = env.fetch("JUMP_GATEWAY_JWKS_URL", nil)
        raw.present? ? ConfigValues.build(raw, allow_localhost: !production).to_s : "#{origin}/.well-known/jwks.json"
      rescue KeyError
        "#{origin}/.well-known/jwks.json"
      end
    ttl_seconds = env.fetch("JUMP_RT_TTL_SECONDS", 5.minutes.to_i).to_i
    audience = env.fetch("JUMP_GATEWAY_AUDIENCE", origin.to_s)
    revoked_kids =
      env.fetch("JUMP_RETURN_REVOKED_KIDS", "").to_s.split(",").each_with_object([]) do |kid, memo|
        stripped = kid.strip
        memo << stripped unless stripped.empty?
      end.freeze
    ConfigValues::JumpGatewayValues.new(origin, jwks_uri, audience, ttl_seconds, revoked_kids).freeze
  end
end
