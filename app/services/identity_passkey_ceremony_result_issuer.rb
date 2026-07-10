# typed: false
# frozen_string_literal: true

class IdentityPasskeyCeremonyResultIssuer
  Candidate = Data.define(:webauthn_id, :public_key, :sign_count, :description, :transports)

  def self.issue!(grant_token:, candidate:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                  now: Time.current)
    new(
      grant_token: grant_token,
      candidate: candidate,
      surface: surface,
      actor_ref: actor_ref,
      session_ref: session_ref,
      operation: operation,
      challenge_id: challenge_id,
      now: now,
    ).issue!
  end

  def initialize(grant_token:, candidate:, surface:, actor_ref:, session_ref:, operation:, challenge_id: nil,
                 now: Time.current)
    @grant_token = grant_token
    @candidate = candidate
    @surface = surface.to_s
    @actor_ref = actor_ref.to_s
    @session_ref = session_ref.to_s
    @operation = operation.to_s
    @challenge_id = challenge_id
    @now = now
  end

  def issue!
    validate_grant!
    IdentityPasskeyCeremonyResult.issue(
      result_claims,
      issuer_id: IdentityPasskeyCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  private

  attr_reader :grant_token, :candidate, :surface, :actor_ref, :session_ref, :operation, :challenge_id, :now

  def validate_grant!
    raise IdentityPasskeyCeremonyContract::Error, "candidate is required" if candidate.blank?
    raise IdentityPasskeyCeremonyContract::Error, "passkey ceremony grant is required" if grant_token.blank?
    raise IdentityPasskeyCeremonyContract::Error,
          "grant surface does not match ceremony" unless grant["surface"].to_s == surface
    raise IdentityPasskeyCeremonyContract::Error,
          "grant actor does not match ceremony" unless grant["actor_ref"].to_s == actor_ref
    raise IdentityPasskeyCeremonyContract::Error,
          "grant session does not match ceremony" unless grant["session_ref"].to_s == session_ref
    raise IdentityPasskeyCeremonyContract::Error,
          "grant operation does not match ceremony" unless grant["operation"].to_s == operation
    raise IdentityPasskeyCeremonyContract::Error,
          "grant jti does not match transaction" unless grant["jti"].to_s == transaction.grant_jti.to_s
    raise IdentityPasskeyCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentityPasskeyCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def grant
    @grant ||= IdentityPasskeyCeremonyGrant.decode(
      grant_token,
      issuer_id: IdentityPasskeyCeremonyContract.acme_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentityPasskeyCeremonyReplayStore.for(surface).find_transaction!(grant["transaction_id"])
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
      "challenge_id" => challenge_id.presence || transaction.transaction_id,
      "expires_at" => transaction.expires_at.to_i,
      "webauthn_id" => candidate.webauthn_id,
      "public_key" => candidate.public_key,
      "sign_count" => candidate.sign_count.to_i,
      "description" => candidate.description,
      "transports" => candidate.transports,
    }.compact
  end
end
