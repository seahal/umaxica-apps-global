# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::Passkeys::VerificationsController < ::Sign::Org::ApplicationController
  include ::VerificationOperator
  include SignWebauthn
  include SignPasskeyCeremonyDelegation
  include ::SignRequiresRecoveryPasscodes
  include ::SignSettingsPasskeyRegistrationEndpoint

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_operator!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create
  before_action :accept_org_passkey_ceremony_grant!, only: :create

  def create = verify_passkey_registration

  private

  def accept_org_passkey_ceremony_grant!
    accept_passkey_ceremony_grant!(surface: "org")
    true
  end

  def passkey_registration_actor = current_operator

  def passkey_registration_surface = "org"

  def passkey_registration_passkeys = current_operator.staff_passkeys

  def passkey_registration_redirect_url
    sign_org_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"))
  end

  def recovery_passcode_requirement_actor = current_operator

  def recovery_passcode_requirement_credential_class = OperatorSecretCredential

  def recovery_passcode_setup_url
    sign_org_settings_secret_credentials_url(
      ri: params[:ri],
      host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )
  end
end
