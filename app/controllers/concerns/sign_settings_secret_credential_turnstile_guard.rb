# typed: false
# frozen_string_literal: true

module SignSettingsSecretCredentialTurnstileGuard
  extend ActiveSupport::Concern

  include ::CloudflareTurnstile

  private

  # Both including controllers guard `create` only, and both answer with an Inertia
  # page: there is no ERB template behind `render :new`, so the surface has to supply
  # the re-render. Rendering it here raised ActionView::MissingTemplate instead of the
  # 422 the failed challenge is supposed to produce.
  def verify_secret_credential_turnstile!
    return true if cloudflare_turnstile_stealth_validation["success"]

    prepare_secret_credential_turnstile_create_failure
    render_secret_credential_turnstile_create_failure
    false
  end

  def prepare_secret_credential_turnstile_create_failure
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def render_secret_credential_turnstile_create_failure
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end
end
