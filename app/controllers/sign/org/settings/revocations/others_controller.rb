# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::Revocations::OthersController < ::Sign::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!

  def create
    current_operator.staff_tokens.session_inventory.find_each do |token|
      token.revoke! unless token.public_id == current_session_public_id
    end
    redirect_to(sign_org_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end
end
