# typed: false
# frozen_string_literal: true

class Auth::App::Settings::Passkeys::OptionsController < ::Auth::App::ApplicationController
  include ::VerificationClient
  include SignWebauthn
  include SignSettingsPasskeyRegistration
  include ::SignRequiresRecoveryPasscodes
  include ::CloudflareTurnstile
  include ::SignSettingsPasskeyRegistrationEndpoint

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create
  before_action :verify_settings_passkey_turnstile!, only: :create

  def create = render_passkey_registration_options

  private

  def verify_settings_passkey_turnstile!
    return true if cloudflare_turnstile_stealth_validation["success"]

    respond_to do |format|
      format.html do
        redirect_back_or_to(auth_app_settings_passkeys_path(ri: params[:ri]), status: :see_other)
      end
      format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
    end
    false
  end

  def passkey_registration_actor = current_client

  def passkey_registration_surface = "app"

  def passkey_registration_passkeys = current_client.client_passkeys

  def passkey_registration_redirect_url
    auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
  end

  def passkey_registration_log_prefix = "sign.webauthn.registration"

  def recovery_passcode_requirement_active_strong_credential_count
    current_client.client_passkeys.active.count +
      current_client.client_totp_credentials.where(
        user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      ).count
  end

  def recovery_passcode_requirement_actor = current_client

  def recovery_passcode_requirement_credential_class = ClientSecretCredential

  def recovery_passcode_setup_url
    auth_app_settings_secret_credentials_url(
      ri: params[:ri],
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    )
  end

  def recovery_passcode_top_up_actor = current_client

  def recovery_passcode_top_up_credential_class = ClientSecretCredential

  def recovery_passcode_reveal_redirect_url(token)
    auth_app_settings_secrets_url(
      ri: params[:ri],
      token: token,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    )
  end
end
