# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Authentication method effects (app realm).
class AppEnforcementAuthenticationMethodEffect < AppPrincipalRecord
  self.table_name = "app_enforcement_authentication_method_effects"

  METHODS = %w(email telephone secret passkey totp google apple).freeze
  EFFECTS = %w(mutation_locked unusable permanently_frozen).freeze

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :authentication_method_effects

  validates :principal_public_id, presence: true
  validates :authentication_method, presence: true, inclusion: { in: METHODS }
  validates :effect, presence: true, inclusion: { in: EFFECTS }
  validates :effective_at, presence: true
  # D9: permanently_frozen is only legal on permanent_ban and method_protection Cases.
  validate :kind_permits_effect

  private

  def kind_permits_effect
    return unless enforcement_case
    return unless effect == "permanently_frozen"
    return if %w(permanent_ban method_protection).include?(enforcement_case.kind)

    errors.add(:effect, "permanently_frozen is only legal on permanent_ban or method_protection Cases")
  end
end
