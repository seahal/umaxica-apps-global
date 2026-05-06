# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class SessionsController < ApplicationController
        auth_required!

        before_action :authenticate_user!
        before_action :set_session, only: %i(destroy)

        def index
          @sessions = visible_sessions.order(created_at: :desc)

          respond_to do |format|
            format.html
            format.json do
              render json: { sessions: @sessions.map { |s|
                { public_id: s.public_id, created_at: s.created_at }
              } }
            end
          end
        end

        def destroy
          if @session.public_id == current_session_public_id
            return render_current_session_error
          end

          revoke_sessions!([@session])
          render_revoke_success
        end

        def others
          revoke_sessions!(other_active_sessions)
          render_revoke_success
        end

        private

        def visible_sessions
          current_user.user_tokens.session_inventory
        end

        def render_revoke_success
          redirect_to(
            sign_app_configuration_sessions_path,
            status: :see_other,
            notice: t("session_limit.sessions_revoked"),
          )
        end

        def other_active_sessions
          sessions = visible_sessions
          return sessions if current_session_public_id.blank?

          sessions.where.not(public_id: current_session_public_id)
        end

        def revoke_sessions!(sessions)
          if sessions.respond_to?(:find_each)
            sessions.find_each(&:revoke!)
          else
            sessions.each(&:revoke!)
          end
        end

        def render_current_session_error
          redirect_to(
            sign_app_configuration_sessions_path,
            alert: t("session_limit.cannot_revoke_current"),
          )
        end

        def set_session
          @session = visible_sessions.find_by(public_id: params[:id])
          return if @session

          head :not_found
          nil
        end
      end
    end
  end
end
