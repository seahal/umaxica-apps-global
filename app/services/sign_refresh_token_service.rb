# typed: false
# frozen_string_literal: true

# Compatibility namespace. Target-path refresh authority is acme/www.
#
# The rotation, replay-detection, family-revoke, and audit implementation now
# lives physically in `AcmeRefreshTokenService`. This subclass exists only so
# legacy sign-side call sites and tests keep resolving `SignRefreshTokenService`
# (and `SignRefreshTokenService::Result`). It adds no behavior and must not be
# read as implying a sign-side refresh issuer or authority.
class SignRefreshTokenService < ::AcmeRefreshTokenService
end
