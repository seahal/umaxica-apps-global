# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SecretsController < PrivateController
        include ::Verification::Operator

        include ::Sign::Configuration::SecretTurnstileGuard

        include ::Sign::Configuration::SecretCacheControl

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :set_secret, only: %i(show edit update destroy)
        before_action :verify_secret_turnstile!, only: %i(create update destroy)

        def index
          @secrets = current_operator.staff_secrets.order(created_at: :desc)
        end

        def show
        end

        def new
          @secret = current_operator.staff_secrets.new
          @raw_secret = OperatorSecret.generate_raw_secret
          session[:staff_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4)
        end

        def edit
        end

        def create
          raw_secret = session.delete(:staff_secret_raw)
          OperatorSecrets::Create.call(
            actor: current_operator,
            staff: current_operator,
            params: secret_params,
            raw_secret: raw_secret,
          )

          flash[:notice] = t(".created")
          redirect_to(sign_org_configuration_secrets_path)
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record
          @raw_secret = raw_secret.presence || OperatorSecret.generate_raw_secret
          session[:staff_secret_raw] = @raw_secret
          render :new, status: :unprocessable_content
        end

        def update
          if disabling_secret? && AuthMethodGuard.last_method?(current_operator, excluding: @secret)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_org_configuration_secrets_path)
          end

          OperatorSecrets::Update.call(
            actor: current_operator,
            secret: @secret,
            params: secret_params,
          )

          flash[:notice] = t(".updated")
          redirect_to(sign_org_configuration_secrets_path)
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record.is_a?(OperatorSecret) ? e.record : @secret
          render :edit, status: :unprocessable_content
        end

        def destroy
          if AuthMethodGuard.last_method?(current_operator, excluding: @secret)
            flash[:alert] = t(".last_method")
            return redirect_to(sign_org_configuration_secrets_path)
          end

          OperatorSecrets::Destroy.call(actor: current_operator, secret: @secret)
          flash[:notice] = t(".destroyed")
          redirect_to(sign_org_configuration_secrets_path, status: :see_other)
        end

        private

        def set_secret
          @secret = current_operator.staff_secrets.find_by!(public_id: params(:id))
        end

        def secret_params
          params.fetch(:staff_secret, {}).permit(:name, :enabled)
        end

        def disabling_secret?
          secret_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_params[:enabled])
        end

        def prepare_secret_turnstile_create_failure
          @secret = current_operator.staff_secrets.new(secret_params.except(:enabled))
          @raw_secret = session[:staff_secret_raw].presence || OperatorSecret.generate_raw_secret
          session[:staff_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4) if @secret.name.blank?
          @secret.errors.add(:base, t("turnstile_error"))
        end

        def secret_turnstile_failure_redirect_path
          sign_org_configuration_secrets_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(create update destroy).include?(action_name)
        end

        def verification_scope
          "configuration_secret"
        end
      end
    end
  end
end
