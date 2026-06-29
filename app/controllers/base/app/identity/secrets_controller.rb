# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class SecretsController < BaseController
        include CloudflareTurnstile
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_secret_credentials!, only: %i(index show new edit create update destroy)
        step_up only: %i(new create), bootstrap: true
        def index
          @secret_credentials = current_client.client_secret_credentials.order(created_at: :asc)
          render "auth/app/settings/secret_credentials/index"
        end

        def show
          set_secret_credential
          authorize!(@secret_credential)
          render "auth/app/settings/secret_credentials/show"
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
          render "auth/app/settings/secret_credentials/new"
        end

        def edit
          set_secret_credential
          authorize!(@secret_credential)
          render "auth/app/settings/secret_credentials/edit"
        end

        def create
          authorize!(ClientSecretCredential, to: :create?)
          result = ClientSecretCredentialsCreate.call(
            actor: current_client,
            user: current_client,
            params: secret_credential_params,
            raw_secret_credential: session.delete(:user_secret_credential_raw),
          )
          reset_secret_credential_ceremony_session!
          redirect_to(
            base_app_identity_secret_path(result.secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def update
          set_secret_credential; authorize!(@secret_credential)
          result = ClientSecretCredentialsUpdate.call(
            actor: current_client, secret_credential: @secret_credential,
            params: secret_credential_params,
          )
          result.secret_credential.errors.empty? ? redirect_to(
            base_app_identity_secret_path(
              result.secret_credential.public_id,
              ri: params[:ri],
            ), status: :see_other,
          ) : render("auth/app/settings/secret_credentials/edit", status: :unprocessable_content)
        end

        def destroy
          secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
          authorize!(secret_credential)
          return redirect_to(
            base_app_identity_secrets_path(ri: params[:ri]),
            status: :see_other,
          ) unless AuthMethodGuard.can_remove_secret_credential?(
            current_client, secret_credential,
          )

          ClientSecretCredentialsDestroy.call(actor: current_client, secret_credential: secret_credential)
          redirect_to(base_app_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_secret_credentials! = authorize!(ClientSecretCredential, to: :index?)

        def set_secret_credential
          @secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params = params.fetch(:user_secret_credential, {}).permit(:name, :enabled)
      end
    end
  end
end
