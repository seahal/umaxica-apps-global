# typed: false
# frozen_string_literal: true

class Auth::Com::Settings::Revocations::AllsController < ::Auth::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!

  def create
    logout_all_sessions_for!(resource: current_visitor, reason: "settings.session.revoke_all")
    redirect_to(sign_com_sign_out_path(ri: params[:ri]), status: :see_other)
  end
end
