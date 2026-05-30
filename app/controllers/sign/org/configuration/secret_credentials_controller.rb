# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SecretCredentialsController < Sign::Org::ApplicationController
        include ::Verification::Operator

        include ::Sign::Configuration::SecretCredentialTurnstileGuard

        include ::Sign::Configuration::SecretCredentialCacheControl

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :verify_secret_credential_turnstile!, only: %i(create update destroy)

        def index
          authorize!(OperatorSecretCredential, to: :index?)
          @secret_credentials = current_operator.staff_secret_credentials.order(created_at: :desc)
        end

        def show
          authorize!(@secret_credential)
        end

        def new
          authorize!(OperatorSecretCredential, to: :new?)
          @secret_credential = current_operator.staff_secret_credentials.new
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
          OperatorSecretCredentials::Create.call(
            actor: current_operator,
            staff: current_operator,
            params: secret_credential_params,
            raw_secret_credential: raw_secret_credential,
          )

          flash[:notice] = t(".created")
          redirect_to(sign_org_configuration_secret_credentials_path)
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
            flash[:alert] = t(".last_method")
            return redirect_to(sign_org_configuration_secret_credentials_path)
          end

          OperatorSecretCredentials::Update.call(
            actor: current_operator,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )

          flash[:notice] = t(".updated")
          redirect_to(sign_org_configuration_secret_credentials_path)
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record.is_a?(OperatorSecretCredential) ? e.record : @secret_credential
          render :edit, status: :unprocessable_content
        end

        def destroy
          authorize!(@secret_credential)
          if AuthMethodGuard.last_method?(current_operator, excluding: @secret_credential)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_org_configuration_secret_credentials_path)
          end

          OperatorSecretCredentials::Destroy.call(actor: current_operator, secret_credential: @secret_credential)
          flash[:notice] = t(".destroyed")
          redirect_to(sign_org_configuration_secret_credentials_path, status: :see_other)
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
          sign_org_configuration_secret_credentials_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(create update destroy).include?(action_name)
        end

        def verification_scope
          "configuration_secret_credential"
        end
      end
    end
  end
end
