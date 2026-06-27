# typed: false
# frozen_string_literal: true

class Auth::Org::Settings::RevocationsController < Auth::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!
  before_action :set_session, only: :create

  def create
    revoke_selected_session!(@session) unless current_session_record?(@session)
    redirect_to(auth_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end

  private

  def set_session
    @session = current_operator.staff_tokens.session_inventory.find_by!(public_id: params.expect(:session_id))
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
