# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Passkeys::VerificationsController < ::Sign::App::ApplicationController
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
    sign_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end

  def passkey_registration_log_prefix = "sign.webauthn.registration"

  def render_passkey_persist_failed(record)
    render plain: record.errors.full_messages.join("\n"), status: :unprocessable_content
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
    sign_app_settings_secrets_url(
      ri: params[:ri],
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    )
  end

  def recovery_passcode_top_up_actor = current_client

  def recovery_passcode_top_up_credential_class = ClientSecretCredential

  def recovery_passcode_reveal_redirect_url(token)
    sign_app_settings_secrets_url(
      ri: params[:ri],
      token: token,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    )
  end
end
