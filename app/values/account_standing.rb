# typed: false
# frozen_string_literal: true

# Read-only, user-facing projection of visible enforcement state. It does not
# become a second enforcement authority: every decision remains owned by its
# realm-local Enforcement Case and effect rows.
class AccountStanding
  LEVELS = %i(good notice limited locked).freeze
  METHOD_RESTRICTIONS = %w(unusable permanently_frozen).freeze

  attr_reader :level, :decisions

  def self.from_cases(cases)
    visible_cases = Array(cases).select { |enforcement_case| visible_in_force?(enforcement_case) }
    new(level: derive_level(visible_cases), decisions: visible_cases.map { |enforcement_case| decision_for(enforcement_case) })
  end

  def initialize(level:, decisions:)
    raise ArgumentError, "unsupported standing level: #{level.inspect}" unless LEVELS.include?(level.to_sym)

    @level = level.to_sym
    @decisions = decisions.freeze
  end

  private_class_method def self.visible_in_force?(enforcement_case)
    enforcement_case.visibility == "visible" && enforcement_case.in_force?
  end

  private_class_method def self.derive_level(cases)
    return :locked if cases.any? { |enforcement_case| access_blocking?(enforcement_case) }
    return :limited if cases.any? { |enforcement_case| method_restricted?(enforcement_case) }
    return :notice if cases.any?

    :good
  end

  private_class_method def self.access_blocking?(enforcement_case)
    enforcement_case.principal_effect&.access_blocking == true
  end

  private_class_method def self.method_restricted?(enforcement_case)
    Array(enforcement_case.authentication_method_effects).any? do |effect|
      METHOD_RESTRICTIONS.include?(effect.effect)
    end
  end

  private_class_method def self.decision_for(enforcement_case)
    {
      public_id: enforcement_case.public_id,
      source_type: "enforcement_case",
      kind: enforcement_case.kind,
      reason_code: enforcement_case.reason_code,
      effective_at: enforcement_case.effective_at,
      expires_at: enforcement_case.expires_at,
      actions: actions_for(enforcement_case),
    }.freeze
  end

  private_class_method def self.actions_for(enforcement_case)
    case enforcement_case.release_mode
    when "verification_required"
      ["recovery"].freeze
    when "automatic", "operator", "break_glass_only"
      [].freeze
    else
      raise ArgumentError, "unsupported enforcement release mode: #{enforcement_case.release_mode.inspect}"
    end
  end
end
