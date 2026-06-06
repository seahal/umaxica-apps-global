# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Settings
      class SecretCredentialsController < Acme::Org::ApplicationController
        include ::VerificationOperator
        include ::SignSettingsSecretCredentialTurnstileGuard
        include ::SignSettingsSecretCredentialCacheControl

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :verify_secret_credential_turnstile!, only: %i(update destroy)

        def index
          authorize!(OperatorSecretCredential, to: :index?)
          @secret_credentials = current_operator.staff_secret_credentials.order(created_at: :desc)
        end

        def show
          authorize!(@secret_credential)
        end

        def enrollment
          authorize!(OperatorSecretCredential, to: :create?)
          if current_operator.staff_secret_credentials.count >= OperatorSecretCredential::MAX_SECRETS_PER_STAFF
            redirect_to(
              acme_org_settings_secret_credentials_path(ri: params[:ri]),
              alert: t("errors.messages.too_many", default: "Limit reached"),
              status: :see_other,
            )
            return
          end

          issuance = IdentitySecretCredentialCeremonyGrantIssuer.issue!(
            surface: "org",
            actor_ref: current_operator.public_id,
            session_ref: current_session_public_id,
            operation: "enrollment",
          )
          redirect_to(
            new_sign_org_settings_secret_credential_url(
              ri: params[:ri],
              secret_credential_ceremony_grant: issuance.grant,
              host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"),
            ),
            status: :see_other,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def edit
          authorize!(@secret_credential)
        end

        def update
          authorize!(@secret_credential)
          if disabling_secret_credential? && AuthMethodGuard.last_method?(
            current_operator,
            excluding: @secret_credential,
          )
            flash[:alert] = t("sign.org.settings.secret_credentials.update.last_method")
            return redirect_to(acme_org_settings_secret_credentials_path(ri: params[:ri]))
          end

          OperatorSecretCredentialsUpdate.call(
            actor: current_operator,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )

          flash[:notice] = t("sign.org.settings.secret_credentials.update.updated")
          redirect_to(acme_org_settings_secret_credentials_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record.is_a?(OperatorSecretCredential) ? e.record : @secret_credential
          render :edit, status: :unprocessable_content
        end

        def destroy
          authorize!(@secret_credential)
          if AuthMethodGuard.last_method?(current_operator, excluding: @secret_credential)
            flash[:alert] = t("sign.org.settings.secret_credentials.destroy.last_method")
            return redirect_to(acme_org_settings_secret_credentials_path(ri: params[:ri]))
          end

          OperatorSecretCredentialsDestroy.call(actor: current_operator, secret_credential: @secret_credential)
          flash[:notice] = t("sign.org.settings.secret_credentials.destroy.destroyed")
          redirect_to(acme_org_settings_secret_credentials_path(ri: params[:ri]), status: :see_other)
        end

        private

        def set_secret_credential
          @secret_credential = current_operator.staff_secret_credentials.find_by!(public_id: params(:id))
        end

        def secret_credential_params
          params.fetch(:staff_secret_credential, {}).permit(:name, :enabled)
        end

        def disabling_secret_credential?
          secret_credential_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_credential_params[:enabled])
        end

        def prepare_secret_credential_turnstile_create_failure
          raise NotImplementedError, "acme secret credential lifecycle does not create raw credentials"
        end

        def secret_credential_turnstile_failure_redirect_path
          acme_org_settings_secret_credentials_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(update destroy enrollment).include?(action_name)
        end

        def verification_scope
          "settings_secret_credential"
        end
      end
    end
  end
end
