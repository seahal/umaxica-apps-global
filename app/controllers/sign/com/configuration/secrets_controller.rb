# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class SecretsController < PrivateController
        include ::Verification::Visitor

        include ::Sign::Configuration::SecretTurnstileGuard

        include ::Sign::Configuration::SecretCacheControl

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        before_action :set_secret, only: %i(show edit update destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_turnstile!, only: %i(create update destroy)

        def index
          @secrets = current_visitor.visitor_secrets.order(created_at: :desc)
        end

        def show
        end

        def new
          @secret = current_visitor.visitor_secrets.new
          @raw_secret = VisitorSecret.generate_raw_secret
          session[:visitor_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4)
        end

        def edit
        end

        def create
          raw_secret = session.delete(:visitor_secret_raw)
          @secret = current_visitor.visitor_secrets.new(create_secret_params)
          @secret.raw_secret = raw_secret
          @secret.password = raw_secret
          @secret.save!

          flash[:notice] = t("sign.app.configuration.secrets.create.created")
          redirect_to(sign_com_configuration_secrets_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret ||= e.record
          @raw_secret ||= raw_secret
          render :new, status: :unprocessable_content
        end

        def update
          update_params = secret_params
          if disabling_secret?(update_params) && AuthMethodGuard.last_method?(current_visitor, excluding: @secret)
            flash[:alert] = t("sign.app.configuration.secrets.update.last_method")
            return redirect_to(sign_com_configuration_secrets_path(ri: params[:ri]))
          end

          VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::ACTIVE)
          VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::REVOKED)
          @secret.name = update_params[:name].to_s.strip if update_params[:name].present?
          @secret.visitor_secret_status_id = VisitorSecret.status_id_for(:active) if update_params[:enabled] == "1"
          @secret.visitor_secret_status_id = VisitorSecret.status_id_for(:revoked) if update_params[:enabled] == "0"
          @secret.save!(validate: false)

          flash[:notice] = t("sign.app.configuration.secrets.update.updated")
          redirect_to(sign_com_configuration_secrets_path(ri: params[:ri]))
        rescue ActiveRecord::RecordInvalid => e
          @secret = e.record.is_a?(VisitorSecret) ? e.record : @secret
          render :edit, status: :unprocessable_content
        end

        def destroy
          if AuthMethodGuard.last_method?(current_visitor, excluding: @secret)
            flash[:alert] = t("sign.app.configuration.secrets.destroy.last_method")
            return redirect_to(sign_com_configuration_secrets_path(ri: params[:ri]))
          end

          @secret.update!(visitor_secret_status_id: VisitorSecretStatus::DELETED)
          flash[:notice] = t("sign.app.configuration.secrets.destroy.destroyed")
          redirect_to(sign_com_configuration_secrets_path(ri: params[:ri]), status: :see_other)
        end

        def regenerate
          redirect_to(
            sign_com_configuration_secret_path(@secret.public_id, ri: params[:ri]),
            alert: t("messages.not_implemented"),
            status: :see_other,
          )
        end

        private

        def set_secret
          @secret = current_visitor.visitor_secrets.find_by!(public_id: params(:id))
        end

        def secret_params
          params.fetch(:visitor_secret, params.fetch(:user_secret, {})).permit(:name, :enabled)
        end

        def create_secret_params
          secret_params.except(:enabled)
        end

        def disabling_secret?(params)
          params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(params[:enabled])
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_visitor.has_verified_recovery_identity?

          render plain: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def prepare_secret_turnstile_create_failure
          @secret = current_visitor.visitor_secrets.new(create_secret_params)
          @raw_secret = session[:visitor_secret_raw].presence || VisitorSecret.generate_raw_secret
          session[:visitor_secret_raw] = @raw_secret
          @secret.name = @raw_secret.first(4) if @secret.name.blank?
          @secret.errors.add(:base, t("turnstile_error"))
        end

        def secret_turnstile_failure_redirect_path
          sign_com_configuration_secrets_path(ri: params[:ri])
        end

        def verification_required_action?
          %w(create update destroy regenerate).include?(action_name)
        end

        def verification_scope
          "configuration_secret"
        end
      end
    end
  end
end
