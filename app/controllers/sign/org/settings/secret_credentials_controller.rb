# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      class SecretCredentialsController < ::Sign::Org::ApplicationController
        include ::VerificationOperator

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSecretCredentialCeremonyDelegation

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: []
        before_action :verify_secret_credential_turnstile!, only: :create
        before_action :accept_org_secret_credential_ceremony_grant!, only: %i(new create)

        def index
          redirect_to_acme_settings_authority!
        end

        def show
          redirect_to_acme_settings_authority!
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
          redirect_to_acme_settings_authority!
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

          flash[:notice] = t(".created")
          redirect_to(
            sign_org_settings_secret_credentials_url(
              ri: params[:ri],
              host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
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
          redirect_to_acme_settings_authority!
        end

        def destroy
          redirect_to_acme_settings_authority!
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
          @secret_credential = current_operator.staff_secret_credentials.new(secret_credential_params.except(:enabled))
          @raw_secret_credential = session[:staff_secret_credential_raw].presence ||
            OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def secret_credential_turnstile_failure_redirect_path
          sign_org_settings_secret_credentials_path(ri: params[:ri])
        end

        def accept_org_secret_credential_ceremony_grant!
          return true if accept_secret_credential_ceremony_grant!(surface: "org")

          redirect_to(
            sign_org_settings_secret_credentials_path(ri: params[:ri]),
            alert: I18n.t("errors.messages.invalid"),
            status: :see_other,
          )
          false
        end

        def verification_required_action?
          action_name == "create"
        end

        def verification_scope
          "settings_secret_credential"
        end

        # Compatibility entry only. sign/id owns account-facing secret credential lifecycle.
        def redirect_to_acme_settings_authority!
          redirect_to_acme_authority!(acme_settings_authority_path, query: request.query_parameters)
        end

        def acme_settings_authority_path
          request.path.sub(%r{\A/settings/secret_credentials}, "/settings/secrets")
        end
      end
    end
  end
end
