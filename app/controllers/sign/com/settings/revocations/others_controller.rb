# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Revocations::OthersController < ::Sign::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!

  def create
    current_visitor.visitor_tokens.session_inventory.find_each do |token|
      token.revoke! unless token.public_id == current_session_public_id
    end
    redirect_to(sign_com_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end
end
