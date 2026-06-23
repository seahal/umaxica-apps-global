# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::RevocationsController < Sign::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!
  before_action :set_session, only: :create

  def create
    @session.revoke! unless current_session_record?(@session)
    redirect_to(sign_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end

  private

  def set_session
    @session = current_operator.staff_tokens.session_inventory.find_by!(public_id: params.expect(:session_id))
  end

  def current_session_record?(session)
    session&.public_id == current_session_public_id
  end
end
