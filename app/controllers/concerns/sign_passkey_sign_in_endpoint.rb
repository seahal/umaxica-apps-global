# typed: false
# frozen_string_literal: true

module SignPasskeySignInEndpoint
  extend ActiveSupport::Concern

  include SignWebauthn
  include SignPasskeyAuthentication
  include SignPasskeyAuthenticationHelpers
  include SignPasskeyOptionsFlow
  include SignPasskeyVerificationFlow
  include SignPasskeySignInFlow
  include SignPasskeyLoginResultFlow
  include MinimumResponseBudget
  include CloudflareTurnstile

  private

  def before_passkey_options_request!
    verify_turnstile_stealth!
  end

  def passkey_identifier_required_error_key
    "errors.webauthn.pii_required"
  end

  def allow_passkey_options_for_actor?(actor)
    if session_limit_hard_reject_for?(actor)
      render_session_limit_hard_reject
      return false
    end

    true
  end

  def passkey_success_restricted?(result)
    result[:restricted]
  end

  def minimum_response_budget_enabled?
    action_name == "options"
  end
end
