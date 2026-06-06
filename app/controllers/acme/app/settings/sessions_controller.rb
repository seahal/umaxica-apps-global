# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      class SessionsController < Acme::App::ApplicationController
        include AcmeSettingsSessionManagement

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_session, only: %i(destroy)
        before_action :authorize_sessions!, only: %i(index)
        before_action :authorize_session!, only: %i(destroy)
        before_action :authorize_session_revoke_others!, only: %i(others)
        before_action :authorize_session_revoke_all!, only: %i(revoke_all)
        helper_method :current_session_record?

        def index
          super
          render "acme/shared/settings/sessions/index" unless performed?
        end

        def destroy = super

        def others = super

        def revoke_all = super

        private

        def authorize_sessions!
          authorize!(ClientToken, to: :index?)
        end

        def authorize_session!
          authorize!(@session)
        end

        def authorize_session_revoke_others!
          authorize!(ClientToken, to: :revoke_others?)
        end

        def authorize_session_revoke_all!
          authorize!(current_client, to: :revoke_all?)
        end

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
          redirect_to(acme_app_settings_sessions_path, status: :see_other, notice: t("session_limit.sessions_revoked"))
        end

        def render_revoke_all_success
          redirect_to(
            acme_app_settings_sessions_path,
            status: :see_other,
            notice: t("session_limit.all_sessions_revoked"),
          )
        end

        def record_session_revoke_activity(action:, revoked_count:)
          SignAppSessionRevokeAudit.record!(
            actor: current_client,
            revoked_session_count: revoked_count,
            action: action,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
        end

        def render_current_session_error
          redirect_to(acme_app_settings_sessions_path, alert: t("session_limit.cannot_revoke_current"))
        end
      end
    end
  end
end
