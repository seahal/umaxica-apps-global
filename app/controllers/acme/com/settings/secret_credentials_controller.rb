# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Settings
      class SecretCredentialsController < Acme::Com::ApplicationController
        include ::Verification::Visitor
        include ::Sign::Settings::SecretCredentialTurnstileGuard
        include ::Sign::Settings::SecretCredentialCacheControl

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :verify_secret_credential_turnstile!, only: %i(update destroy)

        def index
          authorize!(VisitorSecretCredential, to: :index?)
          @secret_credentials = current_visitor.visitor_secret_credentials.order(created_at: :desc)
        end

        def show
          authorize!(@secret_credential)
        end

        def enrollment
          authorize!(VisitorSecretCredential, to: :create?)
          if current_visitor.visitor_secret_credentials.count >= VisitorSecretCredential::MAX_SECRETS_PER_VISITOR
            redirect_to(
              acme_com_settings_secret_credentials_path(ri: params[:ri]),
              alert: t("errors.messages.too_many", default: "Limit reached"),
              status: :see_other,
            )
            return
          end

          issuance = Identity::SecretCredentialCeremony::GrantIssuer.issue!(
            surface: "com",
            actor_ref: current_visitor.public_id,
            session_ref: current_session_public_id,
            operation: "enrollment",
          )
          redirect_to(
            new_sign_com_settings_secret_credential_url(
              ri: params[:ri],
              secret_credential_ceremony_grant: issuance.grant,
              host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def edit
          authorize!(@secret_credential)
        end

        def update
          authorize!(@secret_credential)
          update_params = secret_credential_params
          if disabling_secret_credential?(update_params) && AuthMethodGuard.last_method?(
            current_visitor,
            excluding: @secret_credential,
          )
            flash[:alert] = t("sign.app.settings.secret_credentials.update.last_method")
            return redirect_to(acme_com_settings_secret_credentials_path(ri: params[:ri]))
          end

          VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
          VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::REVOKED)
          @secret_credential.name = update_params[:name].to_s.strip if update_params[:name].present?
          if update_params[:enabled] == "1"
            @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(:active)
          elsif update_params[:enabled] == "0"
            @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(:revoked)
          end
          @secret_credential.save!(validate: false)

          flash[:notice] = t("sign.app.settings.secret_credentials.update.updated")
          redirect_to(acme_com_settings_secret_credentials_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record.is_a?(VisitorSecretCredential) ? e.record : @secret_credential
          render :edit, status: :unprocessable_content
        end

        def destroy
          authorize!(@secret_credential)
          if AuthMethodGuard.last_method?(current_visitor, excluding: @secret_credential)
            flash[:alert] = t("sign.app.settings.secret_credentials.destroy.last_method")
            return redirect_to(acme_com_settings_secret_credentials_path(ri: params[:ri]))
          end

          @secret_credential.update!(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::DELETED)
          flash[:notice] = t("sign.app.settings.secret_credentials.destroy.destroyed")
          redirect_to(acme_com_settings_secret_credentials_path(ri: params[:ri]), status: :see_other)
        end

        private

        def set_secret_credential
          @secret_credential = current_visitor.visitor_secret_credentials.find_by!(public_id: params(:id))
        end

        def secret_credential_params
          params.fetch(:visitor_secret_credential, params.fetch(:user_secret_credential, {})).permit(:name, :enabled)
        end

        def disabling_secret_credential?(params)
          params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(params[:enabled])
        end

        def prepare_secret_credential_turnstile_create_failure
          raise NotImplementedError, "acme secret credential lifecycle does not create raw credentials"
        end

        def secret_credential_turnstile_failure_redirect_path
          acme_com_settings_secret_credentials_path(ri: params[:ri])
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
