# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, D8: ending a Case closes all its own still-open Effects in the same
# transaction, then releases the principal's administrative lock only if no other Case's Principal
# Effect is still in force for them - the refcount rule.
#
# As with the apply operation, the release runs outside the transaction: the Case is ended whether
# or not the unlock succeeds, and a failed unlock must not resurrect a Case an operator has closed.
#
# This was EnforcementCaseApplicable#end_case!.
class EnforcementCaseEndOperation
  def self.call(...)
    new(...).call
  end

  def initialize(enforcement_case:, reason:, ended_by_operator_public_id: nil)
    @enforcement_case = enforcement_case
    @reason = reason
    @ended_by_operator_public_id = ended_by_operator_public_id
  end

  def call
    unless EnforcementCaseApplicable::END_REASONS.include?(reason.to_s)
      raise ArgumentError, "reason must be one of #{EnforcementCaseApplicable::END_REASONS}"
    end

    now = Time.current
    enforcement_case.class.transaction do
      enforcement_case.update!(
        ended_at: now,
        end_reason: reason,
        ended_by_operator_public_id: ended_by_operator_public_id,
      )
      enforcement_case.principal_effect&.update!(ended_at: now)
      # rubocop:disable Rails/SkipsModelValidations
      enforcement_case.authentication_method_effects.where(ended_at: nil).update_all(ended_at: now)
      enforcement_case.identifier_effects.where(ended_at: nil).update_all(ended_at: now)
      # rubocop:enable Rails/SkipsModelValidations
    end

    release_principal_access_effect!
    enforcement_case.write_audit_event!((reason == "expired") ? "expired" : "ended")

    true
  end

  private

  attr_reader :enforcement_case, :reason, :ended_by_operator_public_id

  def release_principal_access_effect!
    effect = enforcement_case.principal_effect
    return unless effect&.access_blocking?
    return if other_blocking_case_in_force?

    principal = enforcement_case.class.principal_class.find_by(public_id: enforcement_case.principal_public_id)
    return unless principal

    operator = ::Operator.find_by(public_id: enforcement_case.applied_by_operator_public_id)
    return unless operator

    AdministrativeAccessLock.unlock!(
      account: principal,
      operator: operator,
      reason_code: enforcement_case.reason_code,
      ticket_id: enforcement_case.ticket_id,
      metadata: { enforcement_case_public_id: enforcement_case.public_id },
    )
  end

  def other_blocking_case_in_force?
    enforcement_case.class.in_force
      .where(principal_public_id: enforcement_case.principal_public_id)
      .where.not(id: enforcement_case.id)
      .joins(:principal_effect)
      .merge(enforcement_case.principal_effect.class.where(access_blocking: true))
      .exists?
  end
end
