# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Reconciliation: EnforcementCase#apply! commits
# the security decision atomically, but session revocation and the audit
# write happen after commit and can fail independently. This job finds every
# active Case across all three realms whose convergent side effects have not
# yet completed (sessions_revoked_at / audited_at still nil) and retries
# them. Idempotent by construction: revoke! on an already-revoked token and
# EnforcementEvent.create! are both safe to repeat, and a Case's own
# `applied` audit event is only re-attempted if audited_at is still nil.
class EnforcementReconciliationJob < ApplicationJob
  queue_as :retention

  CASE_CLASSES = [AppEnforcementCase, ComEnforcementCase, OrgEnforcementCase].freeze

  def perform(batch_size: 200)
    CASE_CLASSES.each do |case_class|
      case_class.pending_convergence.in_batches(of: batch_size) do |batch|
        batch.find_each { |enforcement_case| reconcile!(enforcement_case) }
      end
    end
  end

  private

  def reconcile!(enforcement_case)
    enforcement_case.revoke_method_sessions! if enforcement_case.sessions_revoked_at.blank?
    enforcement_case.write_audit_event!("revocation_reconciled") if enforcement_case.audited_at.blank?
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "enforcement.reconciliation.failed",
        case_public_id: enforcement_case.public_id,
        error_class: e.class.name,
      ),
    )
  end
end
