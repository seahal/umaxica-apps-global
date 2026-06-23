# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SessionsController < ::Sign::App::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_session, only: %i(show destroy)

        helper_method :current_session_record?

        def index
          @sessions = visible_sessions.order(created_at: :desc)
        end

        def show
          render :show
        end

        def destroy
          return redirect_to(
            sign_app_settings_sessions_path(ri: params[:ri]),
            status: :see_other,
          ) if current_session_record?(@session)

          @session.revoke!
          redirect_to(sign_app_settings_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def visible_sessions
          current_client.client_tokens.session_inventory
        end

        def set_session
          @session = visible_sessions.find_by!(public_id: params.expect(:id))
        end

        def current_session_record?(session)
          session&.public_id == current_session_public_id
        end
      end
    end
  end
end
