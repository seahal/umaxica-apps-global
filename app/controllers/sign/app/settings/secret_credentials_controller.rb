# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SecretCredentialsController < Sign::App::ApplicationController
        include ::Verification::Client

        include ::Sign::Settings::SecretCredentialTurnstileGuard

        include ::Sign::Settings::SecretCredentialCacheControl
        include ::Sign::AcmeAuthorityRedirect
        include ::Sign::SecretCredentialCeremonyDelegation

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_no_store_for_secret_credential_pages
        step_up only: %i(new create)
        before_action :set_secret_credential, only: :regenerate
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: :create
        before_action :accept_app_secret_credential_ceremony_grant!, only: %i(new create)

        def index
          redirect_to_acme_settings_authority!
        end

        def show
          redirect_to_acme_settings_authority!
        end

        def new
          authorize!(ClientSecretCredential, to: :new?)
          @secret_credential = current_client.client_secret_credentials.new
          start_secret_credential_ceremony!(
            surface: "app", actor: current_client,
            session_ref: current_session_public_id,
          )
          @raw_secret_credential = ClientSecretCredential.generate_raw_secret_credential
          session[:user_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
        end

        def edit
          redirect_to_acme_settings_authority!
        end

        def create
          authorize!(ClientSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:user_secret_credential_raw)
          finish_secret_credential_ceremony!(
            surface: "app",
            actor: current_client,
            session_ref: current_session_public_id,
            record_class: ClientSecretCredential,
            name: secret_credential_params[:name].to_s.strip,
            enabled: secret_credential_params[:enabled],
            raw_secret_credential: raw_secret_credential,
          )
          reset_secret_credential_ceremony_session!
          record_secret_credential_registration_step_up!

          flash[:notice] = t(".created")
          redirect_to(
            acme_app_settings_secret_credentials_url(
              ri: params[:ri],
              host: ENV.fetch(
                "ACME_SERVICE_URL", "www.app.localhost",
              ),
            ), allow_other_host: cross_host_redirect_allowed?,
          )
        rescue ActiveRecord::RecordInvalid => e
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        def update
          redirect_to_acme_settings_authority!
        end

        def destroy
          redirect_to_acme_settings_authority!
        end

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

        def set_secret_credential
          @secret_credential = current_client.client_secret_credentials.find_by!(public_id: params(:id))
        end

        def secret_credential_params
          params.fetch(:user_secret_credential, {}).permit(:name, :enabled)
        end

        def disabling_secret_credential?
          secret_credential_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_credential_params[:enabled])
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_client.has_verified_recovery_identity?

          render plain: Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def record_secret_credential_registration_step_up!
          true
        end

        def prepare_secret_credential_turnstile_create_failure
          @secret_credential = current_client.client_secret_credentials.new(secret_credential_params.except(:enabled))
          @raw_secret_credential = session[:user_secret_credential_raw].presence ||
            ClientSecretCredential.generate_raw_secret_credential
          session[:user_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def secret_credential_turnstile_failure_redirect_path
          sign_app_settings_secret_credentials_path(ri: params[:ri])
        end

        def accept_app_secret_credential_ceremony_grant!
          return true if accept_secret_credential_ceremony_grant!(surface: "app")

          redirect_to(
            acme_app_settings_secret_credentials_path(ri: params[:ri]),
            alert: I18n.t("errors.messages.invalid"),
            status: :see_other,
          )
          false
        end

        def verification_required_action?
          %w(new create regenerate).include?(action_name)
        end

        def verification_scope
          "settings_secret_credential"
        end

        # Compatibility entry only. acme/www owns account-facing secret credential lifecycle.
        def redirect_to_acme_settings_authority!
          redirect_to_acme_authority!(request.path, query: request.query_parameters)
        end
      end
    end
  end
end
