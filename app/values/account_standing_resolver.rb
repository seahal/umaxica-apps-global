# typed: false
# frozen_string_literal: true

# Reads one realm's visible Enforcement Cases and returns the presentation
# value used by that same realm. Callers must supply their own realm-local
# model class; the resolver never performs a cross-surface lookup.
class AccountStandingResolver
  def self.call(enforcement_case_class:, principal_public_id:)
    cases =
      enforcement_case_class.in_force
        .where(principal_public_id: principal_public_id, visibility: "visible")
        .includes(:principal_effect, :authentication_method_effects)

    AccountStanding.from_cases(cases)
  end
end
