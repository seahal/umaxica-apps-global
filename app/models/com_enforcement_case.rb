# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: Enforcement Case for the com realm (Visitor).
class ComEnforcementCase < ComPrincipalRecord
  include EnforcementCaseApplicable

  self.table_name = "com_enforcement_cases"

  has_one :principal_effect, class_name: "ComEnforcementPrincipalEffect", dependent: :destroy,
                             inverse_of: :enforcement_case
  has_many :authentication_method_effects, class_name: "ComEnforcementAuthenticationMethodEffect",
                                           dependent: :destroy, inverse_of: :enforcement_case
  has_many :identifier_effects, class_name: "ComEnforcementIdentifierEffect", dependent: :destroy,
                                inverse_of: :enforcement_case
  has_many :principal_links, class_name: "ComEnforcementPrincipalLink", dependent: :destroy,
                             inverse_of: :enforcement_case

  def self.principal_class
    ::Visitor
  end

  def self.realm
    "com"
  end
end
