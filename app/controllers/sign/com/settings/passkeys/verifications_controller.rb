# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Passkeys::VerificationsController < ::Sign::Com::ApplicationController
  include ::VerificationVisitor
  include SignWebauthn
  include SignPasskeyCeremonyDelegation
  include ::SignRequiresRecoveryPasscodes
  include ::SignSettingsPasskeyRegistrationEndpoint

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_visitor!
  step_up only: :create, bootstrap: true
  before_action :require_recovery_passcodes_for_mfa_registration!, only: :create
  before_action :accept_com_passkey_ceremony_grant!, only: :create

  def create = verify_passkey_registration

  private

  def accept_com_passkey_ceremony_grant!
    return true if accept_passkey_ceremony_grant!(surface: "com")

    respond_to do |format|
      format.html do
        redirect_to(acme_com_settings_passkeys_path(ri: params[:ri]), status: :see_other)
      end
      format.json { render json: { error: I18n.t("errors.messages.invalid") }, status: :bad_request }
    end
    false
  end

  def passkey_registration_actor = current_visitor

  def passkey_registration_surface = "com"

  def passkey_registration_passkeys = current_visitor.visitor_passkeys

  def passkey_registration_redirect_url
    acme_com_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
  end

  def recovery_passcode_requirement_actor = current_visitor

  def recovery_passcode_requirement_credential_class = VisitorSecretCredential

  def recovery_passcode_setup_url
    acme_com_settings_secret_credentials_url(
      ri: params[:ri],
      host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
    )
  end
end
