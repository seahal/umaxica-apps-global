# typed: false
# frozen_string_literal: true

module CloudflareTurnstile
  extend ActiveSupport::Concern

  VALIDATION_OVERRIDE_ENABLED = Concurrent::AtomicReference.new(false)
  VALIDATION_OVERRIDE_RESPONSE = Concurrent::AtomicReference.new

  class << self
    def validation_override_enabled
      return false unless test_override_allowed?

      VALIDATION_OVERRIDE_ENABLED.value
    end

    def validation_override_enabled=(value)
      assert_test_override_allowed!

      VALIDATION_OVERRIDE_ENABLED.value = value
    end

    def validation_override_response
      return nil unless test_override_allowed?

      VALIDATION_OVERRIDE_RESPONSE.value
    end

    def validation_override_response=(value)
      assert_test_override_allowed!

      VALIDATION_OVERRIDE_RESPONSE.value = value
    end

    alias_method :test_mode, :validation_override_enabled
    alias_method :test_mode=, :validation_override_enabled=
    alias_method :test_validation_response, :validation_override_response
    alias_method :test_validation_response=, :validation_override_response=

    private

    def test_override_allowed?
      defined?(Rails) &&
        Rails.configuration.x.security.try(:allow_turnstile_validation_override) == true
    end

    def assert_test_override_allowed!
      return if test_override_allowed?

      raise RuntimeError, "CloudflareTurnstile validation override is allowed only in test"
    end
  end

  private

  def cloudflare_turnstile_validation
    if CloudflareTurnstile.validation_override_enabled
      return CloudflareTurnstile.validation_override_response || { "success" => true }
    end

    JitSecurityTurnstileVerifier.verify(
      token: request.request_parameters["cf-turnstile-response"].to_s,
      remote_ip: request.remote_ip,
      mode: :visible,
    )
  end

  def cloudflare_turnstile_stealth_validation
    if CloudflareTurnstile.validation_override_enabled
      return CloudflareTurnstile.validation_override_response || { "success" => true }
    end

    JitSecurityTurnstileVerifier.verify(
      token: request.request_parameters["cf-turnstile-response"].to_s,
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
