# typed: false
# frozen_string_literal: true

module CloudflareTurnstile
  extend ActiveSupport::Concern

  private

  def cloudflare_turnstile_validation
    verify_turnstile(mode: :visible)
  end

  def cloudflare_turnstile_stealth_validation
    verify_turnstile(mode: :stealth)
  end

  # TurnstileDegradation only rewrites a result the verifier marked as an upstream
  # outage; a failed challenge stays a failure.
  def verify_turnstile(mode:)
    TurnstileDegradation.apply(
      turnstile_verifier.verify(
        token: request.request_parameters["cf-turnstile-response"].to_s,
        remote_ip: request.remote_ip,
        mode: mode,
      ),
    )
  end

  def turnstile_verifier
    Turnstile::VerifierFactory.current
  end

  def verify_turnstile_stealth!
    result = cloudflare_turnstile_stealth_validation
    return true if result["success"]

    render json: { error: I18n.t("turnstile_error") }, status: :unprocessable_content
    false
  end
end
