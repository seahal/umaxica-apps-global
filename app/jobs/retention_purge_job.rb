# typed: false
# frozen_string_literal: true

class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  # Order matters: rows are deleted with `delete_all`, which fires DB-level FK
  # cascades but not AR callbacks. Tables that hold FK references with
  # ON DELETE CASCADE to other RETAINABLE rows MUST be listed *before* the
  # referenced parent — otherwise the cascade will silently delete rows whose
  # `purged_at` is still Infinity. Concretely: `client_sign_up_cycles.token_id`
  # → `client_tokens.id` ON DELETE CASCADE, so ClientSignUpCycle/VisitorSignUpCycle
  # must precede ClientToken/VisitorToken. Verified by
  # `test/jobs/retention_purge_job_test.rb`.
  RETAINABLE_MODELS = %w(
    Client Visitor Operator AppPreference OrgPreference ComPreference
    ClientSignUpCycle VisitorSignUpCycle
    ClientEmail VisitorEmail ClientTelephone VisitorTelephone
    ClientPasskey VisitorPasskey ClientSocialGoogle ClientSocialApple
    ClientToken OperatorToken VisitorToken
    ClientVerification OperatorVerification VisitorVerification
    ClientAuthorizationCode OperatorAuthorizationCode VisitorAuthorizationCode
    ClientStepUpSession OperatorStepUpSession VisitorStepUpSession
    AreaOccurrence ClientOccurrence VisitorOccurrence OperatorOccurrence ZipOccurrence
    DomainOccurrence IpOccurrence EmailOccurrence JwtOccurrence TelephoneOccurrence
  ).filter_map(&:safe_constantize).freeze

  def perform(batch_size: 500)
    now = Time.current
    SignUp::ArtifactCleanup.cleanup_pending!(now: now, batch_size: batch_size)

    RETAINABLE_MODELS.each do |klass|
      if [Client, Visitor].include?(klass)
        anonymize_accounts(klass, now: now, batch_size: batch_size)
        next
      end

      if klass == Operator
        purge_operators(now: now, batch_size: batch_size)
        next
      end

      klass.where(purged_at: ..now).in_batches(of: batch_size).delete_all
    end
  end

  private

  # Operator rows are removed set-based (no callbacks/`dependent:`), so their
  # non-audit cross-DB children must be purged explicitly before deletion.
  def purge_operators(now:, batch_size:)
    Operator.where(purged_at: ..now).in_batches(of: batch_size) do |batch|
      batch.find_each { |operator| Retention::CrossDatabaseChildPurge.call(actor: operator) }
      batch.delete_all
    end
  end

  # Set `terminated_at` only AFTER PersonalDataAnonymizer succeeds. Otherwise a
  # mid-anonymization failure (cross-DB, can't be atomic) leaves the marker set
  # and subsequent runs skip the row via `where(terminated_at: nil)`, freezing
  # partial anonymization permanently — a GDPR / 個人情報保護法 failure mode.
  def anonymize_accounts(klass, now:, batch_size:)
    klass.where(purged_at: ..now).where(terminated_at: nil).in_batches(of: batch_size) do |batch|
      batch.find_each do |actor|
        Withdrawal::PersonalDataAnonymizer.call(actor: actor)
        if actor.respond_to?(:terminated_at=)
          actor.terminated_at = now
          actor.save!(validate: false)
        end
      end
    end
  end
end
