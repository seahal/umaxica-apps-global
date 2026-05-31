# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class SecretCredentialsController < Sign::Com::ApplicationController
        include ::Verification::Visitor

        include ::Sign::Configuration::SecretCredentialTurnstileGuard

        include ::Sign::Configuration::SecretCredentialCacheControl

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: %i(create update destroy)

        def index
          authorize!(VisitorSecretCredential, to: :index?)
          @secret_credentials = current_visitor.visitor_secret_credentials.order(created_at: :desc)
        end

        def show
          authorize!(@secret_credential)
        end

        def new
          authorize!(VisitorSecretCredential, to: :new?)
          @secret_credential = current_visitor.visitor_secret_credentials.new
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
          @secret_credential = current_visitor.visitor_secret_credentials.new(create_secret_credential_params)
          @secret_credential.raw_secret_credential = raw_secret_credential
          @secret_credential.password = raw_secret_credential
          @secret_credential.save!

          flash[:notice] = t("sign.app.configuration.secret_credentials.create.created")
          redirect_to(sign_com_configuration_secret_credentials_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential ||= e.record
          @raw_secret_credential ||= raw_secret_credential
          render :new, status: :unprocessable_content
        end

        def update
          authorize!(@secret_credential)
          update_params = secret_credential_params
          if disabling_secret_credential?(update_params) && AuthMethodGuard.last_method?(
            current_visitor,
            excluding: @secret_credential,
          )
            flash[:alert] = t("sign.app.configuration.secret_credentials.update.last_method")
            return redirect_to(sign_com_configuration_secret_credentials_path(ri: params[:ri]))
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

          flash[:notice] = t("sign.app.configuration.secret_credentials.update.updated")
          redirect_to(sign_com_configuration_secret_credentials_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record.is_a?(VisitorSecretCredential) ? e.record : @secret_credential
          render :edit, status: :unprocessable_content
        end

        def destroy
          authorize!(@secret_credential)
          if AuthMethodGuard.last_method?(current_visitor, excluding: @secret_credential)
            flash[:alert] = t("sign.app.configuration.secret_credentials.destroy.last_method")
            return redirect_to(sign_com_configuration_secret_credentials_path(ri: params[:ri]))
          end

          @secret_credential.update!(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::DELETED)
          flash[:notice] = t("sign.app.configuration.secret_credentials.destroy.destroyed")
          redirect_to(sign_com_configuration_secret_credentials_path(ri: params[:ri]), status: :see_other)
        end

        def regenerate
          authorize!(@secret_credential)
          redirect_to(
            sign_com_configuration_secret_credential_path(@secret_credential.public_id, ri: params[:ri]),
            alert: t("messages.not_implemented"),
            status: :see_other,
          )
        end

        private

        def set_secret_credential
          @secret_credential = current_visitor.visitor_secret_credentials.find_by!(public_id: params(:id))
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
          sign_com_configuration_secret_credentials_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(create update destroy regenerate).include?(action_name)
        end

        def verification_scope
          "configuration_secret_credential"
        end
      end
    end
  end
end
