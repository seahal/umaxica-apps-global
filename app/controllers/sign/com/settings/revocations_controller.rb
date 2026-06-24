# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::RevocationsController < Sign::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!
  before_action :set_session, only: :create

  def create
    revoke_selected_session!(@session) unless current_session_record?(@session)
    redirect_to(sign_com_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end

  private

  def set_session
    @session = current_visitor.visitor_tokens.session_inventory.find_by!(public_id: params.expect(:session_id))
  end

  def current_session_record?(session)
    session&.public_id == current_session_public_id
  end

  def revoke_selected_session!(session)
    AuthenticationSelectedSessionRevoker.call(
      owner: current_visitor,
      token: session,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
      reason: "settings.session.revoke",
    )
  end
end
