# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      class SessionsController < ::Auth::App::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action :set_session, only: %i(show destroy)

        helper_method :current_session_record?

        def index = redirect_to(base_app_identity_sessions_path(ri: params[:ri]), status: :see_other)

        def show = redirect_to(base_app_identity_session_path(params.expect(:id), ri: params[:ri]), status: :see_other)

        def destroy = head(:gone)

        private

        def visible_sessions = current_client.client_tokens.session_inventory
      end
    end
  end
end
