# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class SessionsController < ApplicationController
        auth_required!

        before_action :authenticate_operator!
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

        def revoke_all
          return if require_step_up!(scope: "session_revoke_all") == false

          sessions = visible_sessions.to_a
          revoke_sessions!(sessions)
          Rails.event.notify(
            "security.session_revoke_all",
            actor_type: current_resource.class.name,
            actor_id: current_resource.id,
            session_count: sessions.length,
          )
          log_out
          render_revoke_all_success
        end

        private

        def visible_sessions
          current_operator.staff_tokens.session_inventory
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
            sign_org_configuration_sessions_path,
            alert: t("sign.org.in.session.cannot_revoke_current"),
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
