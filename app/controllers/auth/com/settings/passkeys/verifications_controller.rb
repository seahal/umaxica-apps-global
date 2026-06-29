# typed: false
# frozen_string_literal: true

class Auth::Com::Settings::Passkeys::VerificationsController < ::Auth::Com::ApplicationController
  include ::VerificationVisitor
  include SignWebauthn
  include SignSettingsPasskeyRegistration
  include ::SignRequiresRecoveryPasscodes
  include ::SignSettingsPasskeyRegistrationEndpoint

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_visitor!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create

  def create = verify_passkey_registration

  private

  def passkey_registration_actor = current_visitor

  def passkey_registration_surface = "com"

  def passkey_registration_passkeys = current_visitor.visitor_passkeys

  def passkey_registration_redirect_url
    auth_com_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"))
  end

  def recovery_passcode_requirement_active_strong_credential_count
    current_visitor.visitor_passkeys.active.count
  end

  def recovery_passcode_requirement_actor = current_visitor

  def recovery_passcode_requirement_credential_class = VisitorSecretCredential

  def recovery_passcode_setup_url
    auth_com_settings_secret_credentials_url(
      ri: params[:ri],
      host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"),
    )
  end

  def recovery_passcode_top_up_actor = current_visitor

  def recovery_passcode_top_up_credential_class = VisitorSecretCredential

  def recovery_passcode_reveal_redirect_url(token)
    auth_com_settings_secrets_url(
      ri: params[:ri],
      token: token,
      host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"),
    )
  end
end
