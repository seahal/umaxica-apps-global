# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class SessionsController < PrivateController
        AUTHENTICATION_MODE = :private

        include Sign::Configuration::SessionManagement

        before_action :authenticate_client!

        private

        def visible_sessions
          current_client.client_tokens.session_inventory
        end

        def session_owner
          current_client
        end

        def revoke_all_reason
          "app_user_logout_all_sessions"
        end

        def render_revoke_success
          redirect_to(
            sign_app_configuration_sessions_path,
            status: :see_other,
            notice: t("session_limit.sessions_revoked"),
          )
        end

        def render_revoke_all_success
          redirect_to(
            sign_app_configuration_sessions_path,
            status: :see_other,
            notice: t("session_limit.all_sessions_revoked"),
          )
        end

        def record_session_revoke_activity(action:, revoked_count:)
          Sign::App::SessionRevokeAudit.record!(
            actor: current_client,
            revoked_session_count: revoked_count,
            action: action,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
        end

        def render_current_session_error
          redirect_to(
            sign_app_configuration_sessions_path,
            alert: t("session_limit.cannot_revoke_current"),
          )
        end
      end
    end
  end
end
