# typed: false
# frozen_string_literal: true

class Auth::Org::Settings::Revocations::AllsController < ::Auth::Org::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!

  def create
    logout_all_sessions_for!(resource: current_operator, reason: "settings.session.revoke_all")
    redirect_to(sign_org_sign_out_path(ri: params[:ri]), status: :see_other)
  end
end
