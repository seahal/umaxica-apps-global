# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class SecretCredentialsController < ::Auth::App::ApplicationController
        include ::VerificationClient

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSettingsSecretCredentialRegistration

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_no_store_for_secret_credential_pages
        step_up only: %i(new create)
        before_action :set_secret_credential, only: :regenerate
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: :create

        def index = redirect_to(acme_app_identity_secrets_path(ri: params[:ri]), status: :see_other)

        def show = redirect_to(acme_app_identity_secret_path(params.expect(:id), ri: params[:ri]), status: :see_other)

        def new = redirect_to(new_acme_app_identity_secret_path(ri: params[:ri]), status: :see_other)

        def edit
          redirect_to(
            edit_acme_app_identity_secret_path(params.expect(:id), ri: params[:ri]),
            status: :see_other,
          )
        end

        def create = head(:gone)

        def update = head(:gone)

        def destroy = head(:gone)

        # Reserved for future secret_credential rotation support.
        def regenerate
          authorize!(@secret_credential)
          redirect_to(
            sign_app_settings_secret_credential_path(@secret_credential.public_id),
            alert: t("messages.not_implemented"),
            status: :see_other,
          )
        end

        private

        def verification_required_action? = false
      end
    end
  end
end
