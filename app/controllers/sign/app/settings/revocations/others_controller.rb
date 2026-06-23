# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Revocations::OthersController < ::Sign::App::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def create
    current_client.client_tokens.session_inventory.find_each do |token|
      token.revoke! unless token.public_id == current_session_public_id
    end
    redirect_to(sign_app_settings_sessions_path(ri: params[:ri]), status: :see_other)
  end
end
