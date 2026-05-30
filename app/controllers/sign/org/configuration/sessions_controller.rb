# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SessionsController < Sign::Org::ApplicationController
        include Sign::Configuration::SessionManagement

        AUTHENTICATION_MODE = :private
        before_action :authenticate_operator!
        before_action :authorize_sessions!, only: %i(index)
        before_action :authorize_session!, only: %i(destroy)
        before_action :authorize_session_revoke_others!, only: %i(others)
        before_action :authorize_session_revoke_all!, only: %i(revoke_all)
        def index = super

        def destroy = super

        def others = super

        def revoke_all = super

        private

        def authorize_sessions!
          authorize!(OperatorToken, to: :index?)
        end

        def authorize_session!
          authorize!(@session)
        end

        def authorize_session_revoke_others!
          authorize!(OperatorToken, to: :revoke_others?)
        end

        def authorize_session_revoke_all!
          authorize!(current_operator, to: :revoke_all?)
        end

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
