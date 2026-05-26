# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SessionsController < PrivateController
        include Sign::Configuration::SessionManagement

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        private

        def visible_sessions
          current_operator.staff_tokens.session_inventory
        end

        def session_owner
          current_operator
        end

        def revoke_all_reason
          "org_operator_logout_all_sessions"
        end

        def session_status_association
          :staff_token_status
        end

        def render_revoke_success
          redirect_to(
            sign_org_configuration_sessions_path,
            status: :see_other,
            notice: t("sign.org.in.session.sessions_revoked"),
          )
        end

        def render_revoke_all_success
          redirect_to(
            sign_org_configuration_sessions_path,
            status: :see_other,
            notice: t("session_limit.all_sessions_revoked"),
          )
        end

        def render_current_session_error
          redirect_to(
            sign_org_configuration_sessions_path,
            alert: t("sign.org.in.session.cannot_revoke_current"),
          )
        end
      end
    end
  end
end
