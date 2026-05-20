# typed: false
# frozen_string_literal: true

class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = %w(
    Client Visitor Operator AppPreference OrgPreference ComPreference
    ClientToken OperatorToken VisitorToken
    ClientVerification OperatorVerification VisitorVerification
    ClientAuthorizationCode OperatorAuthorizationCode VisitorAuthorizationCode
    ClientStepUpSession OperatorStepUpSession VisitorStepUpSession
    AreaOccurrence ClientOccurrence VisitorOccurrence OperatorOccurrence ZipOccurrence
    DomainOccurrence IpOccurrence EmailOccurrence JwtOccurrence TelephoneOccurrence
    AppJumpLink ComJumpLink OrgJumpLink
  ).filter_map(&:safe_constantize).freeze

  def perform(batch_size: 500)
    now = Time.current
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

  def anonymize_accounts(klass, now:, batch_size:)
    klass.where(purged_at: ..now).where(terminated_at: nil).in_batches(of: batch_size) do |batch|
      batch.find_each do |actor|
        if actor.respond_to?(:terminated_at=)
          actor.terminated_at = now
          actor.save!(validate: false)
        end
        Withdrawal::PersonalDataAnonymizer.call(actor: actor)
      end
    end
  end
end
