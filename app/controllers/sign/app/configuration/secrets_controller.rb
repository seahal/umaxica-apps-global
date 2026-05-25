# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class SecretsController < PrivateController
        AUTHENTICATION_MODE = :private

        include ::Verification::Client
        include ::Sign::Configuration::SecretTurnstileGuard
        include ::Sign::Configuration::SecretCacheControl

        before_action :authenticate_client!
        before_action only: %i(new create) do
          require_step_up!(scope: verification_scope)
        end
        before_action :set_secret, only: %i(show edit update destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_turnstile!, only: %i(create update destroy)

        def index
          @secrets = current_client.client_secrets.order(created_at: :desc)
        end

        def show
        end

        def new
          @secret = current_client.client_secrets.new
          @raw_secret = ClientSecret.generate_raw_secret
          session[:user_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4)
        end

        def edit
        end

        def create
          raw_secret = session.delete(:user_secret_raw)
          ClientSecrets::Create.call(
            actor: current_client,
            user: current_client,
            params: secret_params,
            raw_secret: raw_secret,
          )
          record_secret_registration_step_up!

          flash[:notice] = t(".created")
          redirect_to(sign_app_configuration_secrets_path)
        rescue ActiveRecord::RecordInvalid => e
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        def update
          if disabling_secret? && AuthMethodGuard.last_method?(current_client, excluding: @secret)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_app_configuration_secrets_path(ri: params[:ri]))
          end

          ClientSecrets::Update.call(
            actor: current_client,
            secret: @secret,
            params: secret_params,
          )

          flash[:notice] = t(".updated")
          redirect_to(sign_app_configuration_secrets_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record.is_a?(ClientSecret) ? e.record : @secret
          render :edit, status: :unprocessable_content
        end

        def destroy
          if AuthMethodGuard.last_method?(current_client, excluding: @secret)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_app_configuration_secrets_path)
          end

          ClientSecrets::Destroy.call(actor: current_client, secret: @secret)
          flash[:notice] = t(".destroyed")
          redirect_to(sign_app_configuration_secrets_path, status: :see_other)
        end

        # Reserved for future secret rotation support.
        def regenerate
          redirect_to(
            sign_app_configuration_secret_path(@secret.public_id),
            alert: t("messages.not_implemented"),
            status: :see_other,
          )
        end

        private

        def set_secret
          @secret = current_client.client_secrets.find_by!(public_id: params(:id))
        end

        def secret_params
          params.fetch(:user_secret, {}).permit(:name, :enabled)
        end

        def disabling_secret?
          secret_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_params[:enabled])
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_client.has_verified_recovery_identity?

          render plain: Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def record_secret_registration_step_up!
          current_session_token&.update!(
            last_step_up_at: Time.current,
            last_step_up_scope: verification_scope,
          )
        end

        def prepare_secret_turnstile_create_failure
          @secret = current_client.client_secrets.new(secret_params.except(:enabled))
          @raw_secret = session[:user_secret_raw].presence || ClientSecret.generate_raw_secret
          session[:user_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4) if @secret.name.blank?
          @secret.errors.add(:base, t("turnstile_error"))
        end

        def secret_turnstile_failure_redirect_path
          sign_app_configuration_secrets_path(ri: params[:ri])
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "configuration_secret"
        end
      end
    end
  end
end
