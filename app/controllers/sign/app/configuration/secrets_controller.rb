# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class SecretsController < PrivateController
        include ::Verification::Client

        before_action :authenticate_client!
        before_action only: %i(new create) do
          require_step_up!(scope: verification_scope)
        end
        before_action :set_secret, only: %i(show edit destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]

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
