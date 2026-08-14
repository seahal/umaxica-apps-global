# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class SessionsController < BaseController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_session, only: %i(show destroy)
        helper_method :current_session_record?

        def index
          authorize!(ClientToken, to: :index?)
          @sessions = visible_sessions.order(created_at: :desc)
          render "base/app/identity/sessions/index"
        end

        def show
          authorize!(@session)
          render "base/app/identity/sessions/show"
        end

        def destroy
          authorize!(@session)
          return redirect_to(
            base_app_identity_sessions_path(ri: params[:ri]),
            status: :see_other,
          ) if current_session_record?(@session)

          revoke_selected_session!(@session)
          redirect_to(base_app_identity_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def visible_sessions = current_client.client_tokens.session_inventory

        def set_session = @session = visible_sessions.find_by!(public_id: params.expect(:id))

        def current_session_record?(session) = session&.public_id == current_session_public_id

        def revoke_selected_session!(session)
          AuthenticationSelectedSessionRevoker.call(
            owner: current_client,
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
