# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::ConnectionsController < ::Sign::App::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def show
    redirect_to(sign_app_settings_google_path(ri: params[:ri]))
  end
end
