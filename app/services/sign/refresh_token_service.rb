# typed: false
# frozen_string_literal: true

module Sign
  # Compatibility namespace. Target-path refresh authority is acme/www.
  #
  # The rotation, replay-detection, family-revoke, and audit implementation now
  # lives physically in `Acme::RefreshTokenService`. This subclass exists only so
  # legacy sign-side call sites and tests keep resolving `Sign::RefreshTokenService`
  # (and `Sign::RefreshTokenService::Result`). It adds no behavior and must not be
  # read as implying a sign-side refresh issuer or authority.
  class RefreshTokenService < ::Acme::RefreshTokenService
  end
end
