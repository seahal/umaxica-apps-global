# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class SecretsController < ApplicationController
        auth_required!

        include ::Verification::User

        before_action :authenticate_visitor!
        before_action :set_secret, only: %i(show edit destroy regenerate)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]

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
          @secret = current_visitor.visitor_secrets.new(secret_params)
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
          @secret = current_visitor.visitor_secrets.find_by!(public_id: params.expect(:id))
        end

        def secret_params
          params.fetch(:visitor_secret, params.fetch(:user_secret, {})).permit(:name)
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_visitor.has_verified_recovery_identity?

          render plain: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def verification_required_action?
          %w(destroy regenerate).include?(action_name)
        end

        def verification_scope
          "configuration_secret"
        end
      end
    end
  end
end
