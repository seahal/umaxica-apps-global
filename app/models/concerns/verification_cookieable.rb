# typed: false
# frozen_string_literal: true

module VerificationCookieable
  extend ActiveSupport::Concern

  COOKIE_BASENAME = "verification"
  # The verification cookie is host-only (no Domain attribute; see
  # Sign::VerificationAuditAndCookie#set_verification_cookie!), so it uses the
  # `__Host-` prefix rather than `__Secure-`. Gated on
  # Jit::SessionCookieConfig.force_secure? so the prefix is applied in every
  # secure-context environment (production or FORCE_SECURE_COOKIES=1), matching
  # the auth and session cookies. force_secure? implies the Secure attribute,
  # keeping the `__Host-` invariant (Secure + Path=/ + no Domain) intact.
  HOST_COOKIE_PREFIX = "__Host-"

  class_methods do
    def cookie_name
      Jit::SessionCookieConfig.force_secure? ? "#{HOST_COOKIE_PREFIX}#{COOKIE_BASENAME}" : COOKIE_BASENAME
    end
  end
end
