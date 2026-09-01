# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Principal effects (app realm).
class AppEnforcementPrincipalEffect < AppPrincipalRecord
  self.table_name = "app_enforcement_principal_effects"

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :principal_effect

  validates :principal_public_id, presence: true
  validates :effective_at, presence: true
  # D9: method_protection permits no Principal Effect at all.
  validate :kind_permits_principal_effect

  private

  def kind_permits_principal_effect
    return unless enforcement_case

    errors.add(
      :base,
      "method_protection Cases may not carry a Principal Effect",
    ) if enforcement_case.kind == "method_protection"
  end
end
