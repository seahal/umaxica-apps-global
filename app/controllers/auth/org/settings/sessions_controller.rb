# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      class SessionsController < ::Auth::Org::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        before_action :set_session, only: %i(show destroy)

        helper_method :current_session_record?

        def index
          @sessions = visible_sessions.order(created_at: :desc)
        end

        def show
          render :show
        end

        def destroy
          revoke_selected_session!(@session) unless current_session_record?(@session)
          redirect_to(sign_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
        end

        def others
          visible_sessions.find_each do |token|
            revoke_selected_session!(token) unless current_session_record?(token)
          end
          redirect_to(sign_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
        end

        def revoke_all
          logout_all_sessions_for!(resource: current_operator, reason: "settings.session.revoke_all")
          redirect_to(sign_org_sign_out_path(ri: params[:ri]), status: :see_other)
        end

        private

        def visible_sessions
          current_operator.staff_tokens.session_inventory
        end

        def set_session
          @session = visible_sessions.find_by!(public_id: params.expect(:id))
        end

        def current_session_record?(session)
          session&.public_id == current_session_public_id
        end

        def revoke_selected_session!(session)
          AuthenticationSelectedSessionRevoker.call(
            owner: current_operator,
            token: session,
            current_token: current_session,
            current_session_public_id: current_session_public_id,
            reason: "settings.session.revoke",
          )
        end
      end
    end
  end
end
