# typed: false
# frozen_string_literal: true

class Auth::Org::Settings::Revocations::OthersController < ::Auth::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!

  def create
    current_operator.staff_tokens.session_inventory.find_each do |token|
      next if token.public_id == current_session_public_id

      AuthenticationSelectedSessionRevoker.call(
        owner: current_operator,
        token: token,
        current_token: current_session,
        current_session_public_id: current_session_public_id,
        reason: "settings.session.revoke_others",
      )
    end
    redirect_to(auth_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end
end
