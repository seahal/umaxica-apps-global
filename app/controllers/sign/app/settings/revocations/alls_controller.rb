# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Revocations::AllsController < ::Sign::App::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def create
    logout_all_sessions_for!(resource: current_client, reason: "settings.session.revoke_all")
    redirect_to(sign_app_sign_out_path(ri: params[:ri]), status: :see_other)
  end
end
