# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      class SecretCredentialsController < ::Auth::Org::ApplicationController
        include ::VerificationOperator

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSettingsSecretCredentialRegistration

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :verify_secret_credential_turnstile!, only: :create

        def index
          @secret_credentials = current_operator.staff_secret_credentials.order(created_at: :asc)
        end

        def show
          authorize!(@secret_credential)
        end

        def new
          authorize!(OperatorSecretCredential, to: :new?)
          @secret_credential = current_operator.staff_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "org", _actor: current_operator,
            _session_ref: current_session_public_id,
          )
          @raw_secret_credential = OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
        end

        def edit
          authorize!(@secret_credential)
        end

        def create
          authorize!(OperatorSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:staff_secret_credential_raw)
          finish_secret_credential_ceremony!(
            surface: "org",
            actor: current_operator,
            session_ref: current_session_public_id,
            record_class: OperatorSecretCredential,
            name: secret_credential_params[:name].to_s.strip,
            enabled: secret_credential_params[:enabled],
            raw_secret_credential: raw_secret_credential,
          )
          reset_secret_credential_ceremony_session!

          redirect_to(
            auth_org_settings_secret_credentials_url(
              ri: params[:ri],
              host: ENV.fetch("PRIVATE_AUTH_STAFF_URL"),
            ),
            allow_other_host: cross_host_redirect_allowed?,
          )
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record
          @raw_secret_credential = raw_secret_credential.presence ||
            OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          render :new, status: :unprocessable_content
        end

        def update
          authorize!(@secret_credential)

          if disabling_secret_credential? && AuthMethodGuard.last_method?(
            current_operator,
            excluding: @secret_credential,
          )
            redirect_to(
              auth_org_settings_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
            return
          end

          result = OperatorSecretCredentialsUpdate.call(
            actor: current_operator,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )
          redirect_to(
            auth_org_settings_secret_credential_path(result.secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          authorize!(@secret_credential)
          unless AuthMethodGuard.can_remove_secret_credential?(current_operator, @secret_credential)
            redirect_to(
              auth_org_settings_secret_credentials_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          OperatorSecretCredentialsDestroy.call(actor: current_operator, secret_credential: @secret_credential)
          redirect_to(auth_org_settings_secret_credentials_path(ri: params[:ri]), status: :see_other)
        end

        private

        def set_secret_credential
          @secret_credential = current_operator.staff_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params
          params.fetch(:staff_secret_credential, {}).permit(:name, :enabled)
        end

        def disabling_secret_credential?
          secret_credential_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_credential_params[:enabled])
        end

        def prepare_secret_credential_turnstile_create_failure
          @secret_credential = current_operator.staff_secret_credentials.new(secret_credential_params.except(:enabled))
          @raw_secret_credential = session[:staff_secret_credential_raw].presence ||
            OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def secret_credential_turnstile_failure_redirect_path
          auth_org_settings_secret_credentials_path(ri: params[:ri])
        end

        def verification_required_action?
          action_name == "create"
        end

        def verification_scope
          "settings_secret_credential"
        end
      end
    end
  end
end
