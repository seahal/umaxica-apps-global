# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Revocations::AllsController < ::Sign::App::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def create
    current_client.client_tokens.session_inventory.find_each(&:revoke!)
    redirect_to(sign_app_sign_out_path(ri: params[:ri]), status: :see_other)
  end
end
