# typed: false
# frozen_string_literal: true

class IdentityTelephoneCeremonyResultIssuer
  def self.issue!(grant_token:, candidate:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                  attempt_count: nil, now: Time.current)
    new(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      operation: operation,
      challenge_id: challenge_id,
      attempt_count: attempt_count,
      now: now,
    ).issue!
  end

  def initialize(grant_token:, candidate:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                 attempt_count: nil, now: Time.current)
    @grant_token = grant_token
    @candidate = candidate
    @surface = surface.to_s
    @actor_ref = actor_ref.to_s
    @session_ref = session_ref.to_s
    @operation = operation.to_s
    @challenge_id = challenge_id
    @attempt_count = attempt_count
    @now = now
  end

  def issue!
    validate_grant!
    IdentityTelephoneCeremonyResult.issue(
      result_claims,
      issuer_id: IdentityTelephoneCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  private

  attr_reader :grant_token, :candidate, :surface, :actor_ref, :session_ref, :operation, :challenge_id,
              :attempt_count, :now

  def validate_grant!
    raise IdentityTelephoneCeremony::Error, "candidate is required" if candidate.blank?
    raise IdentityTelephoneCeremony::Error, "telephone ceremony grant is required" if grant_token.blank?
    raise IdentityTelephoneCeremony::Error,
          "grant surface does not match ceremony" unless grant["surface"].to_s == surface
    raise IdentityTelephoneCeremony::Error,
          "grant actor does not match ceremony" unless grant["actor_ref"].to_s == actor_ref
    raise IdentityTelephoneCeremony::Error,
          "grant session does not match ceremony" unless grant["session_ref"].to_s == session_ref
    raise IdentityTelephoneCeremony::Error,
          "grant operation does not match ceremony" unless grant["operation"].to_s == operation
    raise IdentityTelephoneCeremony::Error,
          "grant jti does not match transaction" unless grant["jti"].to_s == transaction.grant_jti.to_s
    raise IdentityTelephoneCeremony::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityTelephoneCeremony::Error, "transaction is already consumed" if transaction.consumed?
  end

  def grant
    @grant ||= IdentityTelephoneCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentityTelephoneCeremonyContract.acme_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityTelephoneCeremonyReplayStore.for(surface).find_transaction!(grant["transaction_id"])
  end

  def result_claims
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction.transaction_id,
      "grant_jti" => transaction.grant_jti,
      "result_jti" => SecureRandom.uuid,
      "operation" => operation,
      "verified_at" => now.to_i,
      "challenge_id" => challenge_id.presence || candidate_reference,
      "expires_at" => transaction.expires_at.to_i,
      "telephone_candidate_ref" => candidate_reference,
      "normalized_number_digest" => candidate.number_digest,
      "attempt_count" => attempt_count,
    }.compact
  end

  def candidate_reference
    (candidate.respond_to?(:public_id) && candidate.public_id.present?) ? candidate.public_id : candidate.id.to_s
  end
end
