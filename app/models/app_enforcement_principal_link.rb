# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Principal links (app realm).
class AppEnforcementPrincipalLink < AppPrincipalRecord
  self.table_name = "app_enforcement_principal_links"

  RELATIONSHIP_KINDS = %w(
    target_principal former_principal related_principal
    suspected_duplicate reinstated_principal false_positive
  ).freeze

  belongs_to :enforcement_case, class_name: "AppEnforcementCase", foreign_key: :app_enforcement_case_id,
                                inverse_of: :principal_links

  validates :principal_kind, presence: true
  validates :principal_public_id, presence: true
  validates :relationship_kind, presence: true, inclusion: { in: RELATIONSHIP_KINDS }
  validates :linked_at, presence: true
end
