# typed: false
# frozen_string_literal: true

class Auth::App::Settings::Passkeys::VerificationsController < ::Auth::App::ApplicationController
  include ::VerificationClient
  include SignWebauthn
  include SignSettingsPasskeyRegistration
  include ::SignRequiresRecoveryPasscodes
  include ::SignSettingsPasskeyRegistrationEndpoint

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create

  def create = verify_passkey_registration

  private

  def passkey_registration_actor = current_client

  def passkey_registration_surface = "app"

  def passkey_registration_passkeys = current_client.client_passkeys

  def passkey_registration_redirect_url
    auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("AUTH_SERVICE_URL"))
  end

  def passkey_registration_log_prefix = "sign.webauthn.registration"

  def render_passkey_persist_failed(record)
    render plain: record.errors.full_messages.join("\n"), status: :unprocessable_content
  end

  def render_verification_success(passkey)
    recovery_passcode_top_up = RecoveryPasscodeTopUp.call(
      actor: current_client,
      credential_class: ClientSecretCredential,
      target_count: RecoveryPasscodeTopUp::TARGET_ACTIVE_RECOVERY_PASSCODES,
    )
    redirect_url =
      if recovery_passcode_top_up.raw_values.any?
        reveal = IdentityOneTimeReveal.issue!(
          actor: current_client,
          session_nonce: current_client.public_id,
          value: recovery_passcode_top_up.raw_values,
          purpose: "client.recovery_secret_credential",
          metadata: {},
        )
        auth_app_settings_secrets_url(
          ri: params[:ri],
          token: reveal.token,
          host: ENV.fetch("AUTH_SERVICE_URL"),
        )
      else
        auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("AUTH_SERVICE_URL"))
      end

    render json: {
      status: "ok",
      passkey_id: passkey.id,
      redirect_url: bootstrap_return_path(redirect_url),
    }, status: :created
  end

  def recovery_passcode_requirement_active_strong_credential_count
    current_client.client_passkeys.active.count +
      current_client.client_totp_credentials.where(
        user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      ).count
  end

  def recovery_passcode_requirement_actor = current_client

  def recovery_passcode_requirement_credential_class = ClientSecretCredential

  def recovery_passcode_setup_url
    auth_app_settings_secrets_url(
      ri: params[:ri],
      host: ENV.fetch("AUTH_SERVICE_URL"),
    )
  end

  def recovery_passcode_top_up_actor = current_client

  def recovery_passcode_top_up_credential_class = ClientSecretCredential

  def recovery_passcode_reveal_redirect_url(token)
    auth_app_settings_secrets_url(
      ri: params[:ri],
      token: token,
      host: ENV.fetch("AUTH_SERVICE_URL"),
    )
  end
end
