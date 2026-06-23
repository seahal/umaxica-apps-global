# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SecretCredentialsController < ::Sign::App::ApplicationController
        include ::VerificationClient

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSecretCredentialCeremonyDelegation

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_no_store_for_secret_credential_pages
        step_up only: %i(new create)
        before_action :set_secret_credential, only: :regenerate
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: :create
        before_action :accept_app_secret_credential_ceremony_grant!, only: %i(new create)

        def index
          @secret_credentials = current_client.client_secret_credentials.order(created_at: :asc)
        end

        def show
          set_secret_credential
          authorize!(@secret_credential)
        end

        def new
          authorize!(ClientSecretCredential, to: :new?)
          @secret_credential = current_client.client_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "app", _actor: current_client,
            _session_ref: current_session_public_id,
          )
          @raw_secret_credential = ClientSecretCredential.generate_raw_secret_credential
          session[:user_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
        end

        def edit
          set_secret_credential
          authorize!(@secret_credential)
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
            sign_app_settings_secret_credentials_url(
              ri: params[:ri],
              host: ENV.fetch(
                "ID_SERVICE_URL", "id.app.localhost",
              ),
            ), allow_other_host: cross_host_redirect_allowed?,
          )
        rescue ActiveRecord::RecordInvalid => e
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        def update
          set_secret_credential
          authorize!(@secret_credential)

          if disabling_secret_credential? && AuthMethodGuard.last_method?(current_client, excluding: @secret_credential)
            redirect_to(
              sign_app_settings_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
            return
          end

          result = ClientSecretCredentialsUpdate.call(
            actor: current_client,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )

          if result.secret_credential.errors.empty?
            redirect_to(
              sign_app_settings_secret_credential_path(result.secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
          else
            render :edit, status: :unprocessable_content
          end
        end

        # DELETE /settings/secret_credentials/:id
        def destroy
          secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
          authorize!(secret_credential)
          unless AuthMethodGuard.can_remove_secret_credential?(current_client, secret_credential)
            redirect_to(
              sign_app_settings_secret_credentials_path(ri: params[:ri]),
              alert: t(".last_method"),
              status: :see_other,
            )
            return
          end
          ClientSecretCredentialsDestroy.call(actor: current_client, secret_credential: secret_credential)
          redirect_to(sign_app_settings_secret_credentials_path(ri: params[:ri]), status: :see_other)
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
          @secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
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
            sign_app_settings_secret_credentials_path(ri: params[:ri]),
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

      end
    end
  end
end
