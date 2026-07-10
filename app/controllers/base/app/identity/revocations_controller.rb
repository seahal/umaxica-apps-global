# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class RevocationsController < BaseController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_session, only: :create

        def create
          return redirect_to(
            base_app_identity_sessions_path(ri: params[:ri]),
            status: :see_other,
          ) if current_session_record?(@session)

          AuthenticationSelectedSessionRevoker.call(
            owner: current_client,
            token: @session,
            current_token: current_session,
            current_session_public_id: current_session_public_id,
            reason: "settings.session.revoke",
          )
          redirect_to(base_app_identity_sessions_path(ri: params[:ri]), status: :see_other)
        end

        private

        def set_session
          @session = current_client.client_tokens.session_inventory.find_by!(public_id: params.expect(:session_id))
        end

        def current_session_record?(session) = session&.public_id == current_session_public_id
      end
    end
  end
end
