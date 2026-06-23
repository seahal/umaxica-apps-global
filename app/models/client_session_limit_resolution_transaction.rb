# typed: false
# frozen_string_literal: true

class ClientSessionLimitResolutionTransaction < AppTicketRecord
  STATUS_PENDING = "pending"
  STATUS_SESSION_SELECTED = "session_selected"
  STATUS_RESOLVED = "resolved"
  STATUS_CANCELLED = "cancelled"
  STATUS_EXPIRED = "expired"
  STATUSES = [
    STATUS_PENDING,
    STATUS_SESSION_SELECTED,
    STATUS_RESOLVED,
    STATUS_CANCELLED,
    STATUS_EXPIRED,
  ].freeze
  TTL = 15.minutes

  belongs_to :oidc_authorization_transaction,
             class_name: "ClientOidcAuthorizationTransaction",
             inverse_of: false

  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
  scope :open_status, -> { where(status: [STATUS_PENDING, STATUS_SESSION_SELECTED]) }

  validates :challenge_digest, :actor_type, :actor_ref, :oidc_authorization_transaction_id,
            :status, :expires_at, presence: true
  validates :challenge_digest, uniqueness: true
  validates :actor_type, inclusion: { in: ["Client"] }
  validates :status, inclusion: { in: STATUSES }

  def self.digest_challenge(challenge)
    OpenSSL::Digest::SHA256.hexdigest(challenge.to_s)
  end

  def self.issue_for_oidc!(actor:, oidc_transaction:, audit_context: {}, now: Time.current)
    challenge = SecureRandom.urlsafe_base64(48)
    transaction =
      AppTicketRecord.connected_to(role: :writing) do
        existing = open_status
          .active_at(now)
          .find_by(
            actor_type: actor.class.name,
            actor_ref: actor.public_id,
            oidc_authorization_transaction_id: oidc_transaction.id,
          )
        if existing
          existing.update!(
            challenge_digest: digest_challenge(challenge),
            expires_at: now + TTL,
            audit_context: existing.audit_context.merge(audit_context.compact),
          )
          next existing
        end

        create!(
          challenge_digest: digest_challenge(challenge),
          actor_type: actor.class.name,
          actor_ref: actor.public_id,
          oidc_authorization_transaction: oidc_transaction,
          status: STATUS_PENDING,
          expires_at: now + TTL,
          audit_context: audit_context.compact,
        )
      end

    Issuance.new(transaction: transaction, challenge: challenge)
  end

  def self.find_active_by_challenge(challenge, now: Time.current)
    AppTicketRecord.connected_to(role: :writing) do
      open_status.active_at(now).find_by(challenge_digest: digest_challenge(challenge))
    end
  end

  def pending?
    status == STATUS_PENDING
  end

  def session_selected?
    status == STATUS_SESSION_SELECTED
  end

  def resolved?
    status == STATUS_RESOLVED
  end

  def cancelled?
    status == STATUS_CANCELLED
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i || status == STATUS_EXPIRED
  end

  def mark_session_selected!(session_ref:, now: Time.current)
    update!(
      selected_session_ref: session_ref.to_s,
      selected_at: now,
      status: STATUS_SESSION_SELECTED,
    )
  end

  def mark_resolved!(now: Time.current)
    update!(resolved_at: now, status: STATUS_RESOLVED)
  end

  def finalize!(now: Time.current)
    update!(consumed_at: now, finalized_at: now, status: STATUS_RESOLVED)
  end

  def cancel!(now: Time.current)
    update!(cancelled_at: now, status: STATUS_CANCELLED)
  end

  Issuance = Data.define(:transaction, :challenge)
end
