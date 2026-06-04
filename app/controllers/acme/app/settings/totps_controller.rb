# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class TotpsController < Acme::App::ApplicationController
        include ::Verification::Client

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_totps!, only: :index
        before_action :set_totp, only: %i(edit update destroy)

        def index
          @totps = current_client.client_totp_credentials
        end

        def enrollment
          authorize!(ClientTotpCredential, to: :create?)
          if current_client.client_totp_credentials.count >= ClientTotpCredential::MAX_TOTPS_PER_USER
            redirect_to(
              acme_app_settings_totps_path(ri: params[:ri]),
              alert: t("session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTPS_PER_USER),
              status: :see_other,
            )
            return
          end

          issuance = Identity::TotpCeremony::GrantIssuer.issue!(
            surface: "app",
            actor_ref: current_client.public_id,
            session_ref: current_session_public_id,
            operation: "registration",
          )
          redirect_to(
            new_sign_app_settings_totp_url(
              ri: params[:ri],
              totp_ceremony_grant: issuance.grant,
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            status: :see_other,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def edit
          authorize!(@totp)
        end

        def update
          authorize!(@totp)
          if @totp.update(update_params)
            redirect_to(
              acme_app_settings_totps_path(ri: params[:ri]),
              notice: t("messages.totp_successfully_updated"),
              status: :see_other,
            )
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@totp)
          unless AuthMethodGuard.can_remove_totp?(current_client, @totp)
            redirect_to(
              acme_app_settings_totps_path(ri: params[:ri]),
              alert: t("sign.app.settings.totps.destroy.last_method"),
            )
            return
          end

          @totp.destroy!
          redirect_to(
            acme_app_settings_totps_path(ri: params[:ri]),
            notice: t("messages.totp_successfully_deleted"),
            status: :see_other,
          )
        end

        private

        def authorize_totps!
          authorize!(ClientTotpCredential, to: :index?)
        end

        def set_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params(:id))
        end

        def update_params
          params.fetch(:user_totp_credential, {}).permit(:title)
        end

        def verification_required_action?
          %w(edit update destroy enrollment).include?(action_name)
        end

        def verification_scope
          "settings_totp"
        end
      end
    end
  end
end
