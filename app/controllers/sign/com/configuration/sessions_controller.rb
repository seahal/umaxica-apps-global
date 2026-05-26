# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class SessionsController < PrivateController
        include Sign::Configuration::SessionManagement

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!

        private

        def visible_sessions
          current_visitor.visitor_tokens.session_inventory
        end

        def session_owner
          current_visitor
        end

        def revoke_all_reason
          "com_visitor_logout_all_sessions"
        end

        def session_status_association
          :visitor_token_status
        end

        def render_revoke_success
          redirect_to(
            sign_com_configuration_sessions_path(ri: params[:ri]),
            status: :see_other,
            notice: t("sign.app.configuration.sessions.revoke.success"),
          )
        end

        def render_revoke_all_success
          redirect_to(
            sign_com_configuration_sessions_path(ri: params[:ri]),
            status: :see_other,
            notice: t("session_limit.all_sessions_revoked"),
          )
        end

        def render_current_session_error
          redirect_to(
            sign_com_configuration_sessions_path(ri: params[:ri]),
            alert: t("sign.app.configuration.sessions.revoke.failure"),
          )
        end
      end
    end
  end
end
