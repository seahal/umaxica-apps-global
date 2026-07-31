# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Decides whether a specific authentication method is currently locked for
  # a principal (adr/unified-enforcement.md, authentication method effects).
  # Distinct from login_allowed? (BAN), which only reflects principal-level
  # status and never sees per-method unusable/permanently_frozen effects.
  class AuthenticationMethodLockPolicy
    def locked?(enforcement_case_class:, principal_public_id:, authentication_method:)
      enforcement_case_class.authentication_method_effect_blocking?(
        principal_public_id,
        authentication_method,
      )
    end
  end
end
