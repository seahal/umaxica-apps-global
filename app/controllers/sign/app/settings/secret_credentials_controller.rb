# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SecretCredentialsController < Sign::App::ApplicationController
        include ::Verification::Client

        include ::Sign::Settings::SecretCredentialTurnstileGuard

        include ::Sign::Settings::SecretCredentialCacheControl

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_no_store_for_secret_credential_pages
        step_up only: %i(new create)
        before_action :set_secret_credential, only: %i(show edit update destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: %i(create update destroy)

        def index
          authorize!(ClientSecretCredential, to: :index?)
          @secret_credentials = current_client.client_secret_credentials.order(created_at: :desc)
        end

        def show
          authorize!(@secret_credential)
        end

        def new
          authorize!(ClientSecretCredential, to: :new?)
          @secret_credential = current_client.client_secret_credentials.new
          @raw_secret_credential = ClientSecretCredential.generate_raw_secret_credential
          session[:user_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
        end

        def edit
          authorize!(@secret_credential)
        end

        def create
          authorize!(ClientSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:user_secret_credential_raw)
          ClientSecretCredentials::Create.call(
            actor: current_client,
            user: current_client,
            params: secret_credential_params,
            raw_secret_credential: raw_secret_credential,
          )
          record_secret_credential_registration_step_up!

          flash[:notice] = t(".created")
          redirect_to(sign_app_settings_secret_credentials_path)
        rescue ActiveRecord::RecordInvalid => e
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        def update
          authorize!(@secret_credential)
          if disabling_secret_credential? && AuthMethodGuard.last_method?(current_client, excluding: @secret_credential)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_app_settings_secret_credentials_path(ri: params[:ri]))
          end

          ClientSecretCredentials::Update.call(
            actor: current_client,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )

          flash[:notice] = t(".updated")
          redirect_to(sign_app_settings_secret_credentials_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record.is_a?(ClientSecretCredential) ? e.record : @secret_credential
          render :edit, status: :unprocessable_content
        end

        def destroy
          authorize!(@secret_credential)
          if AuthMethodGuard.last_method?(current_client, excluding: @secret_credential)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_app_settings_secret_credentials_path)
          end

          ClientSecretCredentials::Destroy.call(actor: current_client, secret_credential: @secret_credential)
          flash[:notice] = t(".destroyed")
          redirect_to(sign_app_settings_secret_credentials_path, status: :see_other)
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

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_secret_credential"
        end
      end
    end
  end
end
