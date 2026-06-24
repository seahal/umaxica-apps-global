# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Revocations::OthersController < ::Sign::App::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def create
    current_client.client_tokens.session_inventory.find_each do |token|
      next if token.public_id == current_session_public_id

      AuthenticationSelectedSessionRevoker.call(
        owner: current_client,
        token: token,
        current_token: current_session,
        current_session_public_id: current_session_public_id,
        reason: "settings.session.revoke_others",
      )
    end
    redirect_to(sign_app_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end
end
