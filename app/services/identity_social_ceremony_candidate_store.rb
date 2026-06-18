# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyCandidateStore
  Candidate = Data.define(
    :ref,
    :digest,
    :surface,
    :actor_ref,
    :session_ref,
    :transaction_id,
    :operation,
    :provider,
    :auth_hash,
    :expires_at,
  )

  def self.store!(**attributes)
    new.store!(**attributes)
  end

  def self.fetch!(ref)
    new.fetch!(ref)
  end

  def self.consume!(ref)
    new.consume!(ref)
  end

  def self.delete(ref)
    new.delete(ref)
  end

  def store!(surface:, actor_ref:, session_ref:, transaction_id:, operation:, provider:, auth_hash:, expires_at:)
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is required" if auth_hash.blank?

    sanitized_auth_hash = auth_hash.to_h.deep_stringify_keys
    record =
      IdentitySocialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
        IdentitySocialCeremonyCandidate.create!(
          ref: SecureRandom.uuid,
          digest: digest_for(
            surface, actor_ref, session_ref, transaction_id, operation, provider,
            sanitized_auth_hash,
          ),
          surface: surface.to_s,
          actor_ref: actor_ref.to_s,
          session_ref: session_ref.to_s,
          transaction_id: transaction_id.to_s,
          operation: operation.to_s,
          provider: provider.to_s,
          auth_hash: sanitized_auth_hash,
          expires_at: expires_at,
        )
      end
    candidate_from(record)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def fetch!(ref)
    record = IdentitySocialCeremonyCandidate.find_active_by_ref!(
      ref,
      now: Time.current,
      error_class: IdentitySocialCeremonyContract::Error,
      not_found_message: "social auth candidate is not found",
      expired_message: "social auth candidate is expired",
    )
    candidate_from(record)
  rescue KeyError, TypeError, ActiveRecord::SerializationTypeMismatch => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def consume!(ref)
    record = IdentitySocialCeremonyCandidate.new(ref: ref.to_s).consume!(
      now: Time.current,
      error_class: IdentitySocialCeremonyContract::Error,
      not_found_message: "social auth candidate is not found",
      expired_message: "social auth candidate is expired",
    )
    candidate_from(record)
  rescue KeyError, TypeError, ActiveRecord::SerializationTypeMismatch => e
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid: #{e.message}"
  end

  def delete(ref)
    IdentitySocialCeremonyCandidate.connection_owner.connected_to(role: :writing) do
      record = IdentitySocialCeremonyCandidate.find_by(ref: ref.to_s)
      record&.update!(consumed_at: Time.current)
    end
  end

  private

  def candidate_from(record)
    raise IdentitySocialCeremonyContract::Error, "social auth candidate is invalid" unless record.valid?

    Candidate.new(
      ref: record.ref,
      digest: record.digest,
      surface: record.surface,
      actor_ref: record.actor_ref,
      session_ref: record.session_ref,
      transaction_id: record.transaction_id,
      operation: record.operation,
      provider: record.provider,
      auth_hash: OmniAuth::AuthHash.new(record.auth_hash),
      expires_at: record.expires_at,
    )
  end

  def digest_for(surface, actor_ref, session_ref, transaction_id, operation, provider, auth_hash)
    uid = SocialAuthUidExtractor.call(auth_hash: auth_hash)
    data = [surface, actor_ref, session_ref, transaction_id, operation, provider, uid].map(&:to_s).join(":")
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, data)
  end
end
