# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class SecretCredentialsController < ::Sign::Com::ApplicationController
        include ::VerificationVisitor

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSecretCredentialCeremonyDelegation

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: :create
        before_action :accept_com_secret_credential_ceremony_grant!, only: %i(new create)

        def index
          @secret_credentials = current_visitor.visitor_secret_credentials.order(created_at: :asc)
        end

        def show
          authorize!(@secret_credential)
        end

        def new
          authorize!(VisitorSecretCredential, to: :new?)
          @secret_credential = current_visitor.visitor_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "com", _actor: current_visitor,
            _session_ref: current_session_public_id,
          )
          @raw_secret_credential = VisitorSecretCredential.generate_raw_secret_credential
          session[:visitor_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
        end

        def edit
          authorize!(@secret_credential)
        end

        def create
          authorize!(VisitorSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:visitor_secret_credential_raw)
          finish_secret_credential_ceremony!(
            surface: "com",
            actor: current_visitor,
            session_ref: current_session_public_id,
            record_class: VisitorSecretCredential,
            name: create_secret_credential_params[:name].to_s.strip,
            enabled: secret_credential_params[:enabled],
            raw_secret_credential: raw_secret_credential,
          )
          reset_secret_credential_ceremony_session!

          flash[:notice] = t("sign.app.settings.secret_credentials.create.created")
          redirect_to(
            sign_com_settings_secret_credentials_url(
              ri: params[:ri],
              host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
            ),
            allow_other_host: cross_host_redirect_allowed?,
          )
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential ||= e.record
          @raw_secret_credential ||= raw_secret_credential
          render :new, status: :unprocessable_content
        end

        def update
          authorize!(@secret_credential)

          if disabling_secret_credential?(secret_credential_params) &&
              AuthMethodGuard.last_method?(current_visitor, excluding: @secret_credential)
            redirect_to(
              sign_com_settings_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
            return
          end

          apply_secret_credential_update!
          redirect_to(
            sign_com_settings_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          authorize!(@secret_credential)
          unless AuthMethodGuard.can_remove_secret_credential?(current_visitor, @secret_credential)
            redirect_to(
              sign_com_settings_secret_credentials_path(ri: params[:ri]),
              alert: t("sign.app.settings.secret_credentials.destroy.last_method"),
              status: :see_other,
            )
            return
          end
          @secret_credential.discard_now!(purge_after: 1.day)
          @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(:deleted)
          @secret_credential.save!
          redirect_to(sign_com_settings_secret_credentials_path(ri: params[:ri]), status: :see_other)
        end

        def regenerate
          authorize!(@secret_credential)
          redirect_to(
            sign_com_settings_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
            alert: t("messages.not_implemented"),
            status: :see_other,
          )
        end

        private

        def set_secret_credential
          @secret_credential = current_visitor.visitor_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params
          params.fetch(:visitor_secret_credential, params.fetch(:user_secret_credential, {})).permit(:name, :enabled)
        end

        def create_secret_credential_params
          secret_credential_params.except(:enabled)
        end

        def disabling_secret_credential?(params)
          params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(params[:enabled])
        end

        def apply_secret_credential_update!
          attrs = secret_credential_params
          @secret_credential.name = attrs[:name].to_s.strip if attrs[:name].present?
          if attrs.key?(:enabled)
            status = ActiveModel::Type::Boolean.new.cast(attrs[:enabled]) ? :active : :revoked
            @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(status)
          end
          @secret_credential.save!
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_visitor.has_verified_recovery_identity?

          render plain: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def prepare_secret_credential_turnstile_create_failure
          @secret_credential = current_visitor.visitor_secret_credentials.new(create_secret_credential_params)
          @raw_secret_credential = session[:visitor_secret_credential_raw].presence ||
            VisitorSecretCredential.generate_raw_secret_credential
          session[:visitor_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def secret_credential_turnstile_failure_redirect_path
          sign_com_settings_secret_credentials_path(ri: params[:ri])
        end

        def accept_com_secret_credential_ceremony_grant!
          accept_secret_credential_ceremony_grant!(surface: "com")
          true
        end

        def verification_required_action?
          %w(create regenerate).include?(action_name)
        end

        def verification_scope
          "settings_secret_credential"
        end
      end
    end
  end
end
