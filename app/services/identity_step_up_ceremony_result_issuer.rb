# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyResultIssuer
  def self.issue!(surface:, actor_ref:, session_ref:, transaction_id:, grant_jti:, scope:, aal:, method:,
                  challenge_id:, expires_at:, attempt_count: nil, now: Time.current)
    IdentityStepUpCeremonyResult.issue(
      {
        "surface" => surface.to_s,
        "actor_ref" => actor_ref.to_s,
        "session_ref" => session_ref.to_s,
        "transaction_id" => transaction_id.to_s,
        "grant_jti" => grant_jti.to_s,
        "result_jti" => SecureRandom.uuid,
        "scope" => scope.to_s,
        "aal" => aal.to_s,
        "method" => method.to_s,
        "verified_at" => now.to_i,
        "challenge_id" => challenge_id.to_s,
        "expires_at" => expires_at.to_i,
        "attempt_count" => attempt_count,
      }.compact,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id(surface),
      now: now,
    )
  end
end
