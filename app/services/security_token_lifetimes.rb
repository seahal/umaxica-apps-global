# typed: false
# frozen_string_literal: true

# Application-level token lifetime and key-rotation policy.
#
# Keep family-specific values out of Jit::Security::Jwt so the low-level
# JWT/JWS/JWK/JWKS layer does not know about Auth, Preference, OIDC, or
# JumpRT token families.
module SecurityTokenLifetimes
  AUTH_ACCESS_JWT_TTL = 1.hour
  PREFERENCE_JWT_TTL = 7.days
  OIDC_ID_TOKEN_TTL = 5.minutes
  JUMP_RT_TTL = 5.minutes

  JWKS_ROTATION_LEEWAY = 1.hour
  CDN_STALE_LEEWAY = 1.hour

  module_function

  def old_kid_verification_window(ttl)
    ttl + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY
  end
end
