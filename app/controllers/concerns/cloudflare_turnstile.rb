# typed: false
# frozen_string_literal: true

module CloudflareTurnstile
  extend ActiveSupport::Concern

  # Test helper for mocking Turnstile responses in tests

  class << self
    def test_mode
      Thread.current[:cloudflare_turnstile_test_mode]
    end

    def test_mode=(value)
      Thread.current[:cloudflare_turnstile_test_mode] = value
    end

    def test_validation_response
      Thread.current[:cloudflare_turnstile_test_validation_response]
    end

    def test_validation_response=(value)
      Thread.current[:cloudflare_turnstile_test_validation_response] = value
    end
  end

  private

  def cloudflare_turnstile_validation
    # In test mode, return the mock response
    if CloudflareTurnstile.test_mode
      Jit::Security::TurnstileVerifier.test_mode = true
      Jit::Security::TurnstileVerifier.test_response = CloudflareTurnstile.test_validation_response
      return CloudflareTurnstile.test_validation_response || { "success" => true }
    end

    Jit::Security::TurnstileVerifier.verify(
      token: params.expect("cf-turnstile-response").to_s,
      remote_ip: request.remote_ip,
      mode: :visible,
    )
  end

  def cloudflare_turnstile_stealth_validation
    # In test mode, return the mock response
    if CloudflareTurnstile.test_mode
      Jit::Security::TurnstileVerifier.test_mode = true
      Jit::Security::TurnstileVerifier.test_response = CloudflareTurnstile.test_validation_response
      return CloudflareTurnstile.test_validation_response || { "success" => true }
    end

    Jit::Security::TurnstileVerifier.verify(
      token: params.expect("cf-turnstile-response").to_s,
      remote_ip: request.remote_ip,
      mode: :stealth,
    )
  end

  def verify_turnstile_stealth!
    result = cloudflare_turnstile_stealth_validation
    return true if result["success"]

    render json: { error: I18n.t("turnstile_error") }, status: :unprocessable_content
    false
  end
end
