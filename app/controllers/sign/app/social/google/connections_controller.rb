# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::ConnectionsController < ::Sign::App::Social::AuthenticationsController
  AUTHENTICATION_MODE = :open

  declare_authentication_mode! :open
  declare_authentication_mode! :private, only: :show

  before_action :authenticate_client!, only: :show
  before_action :require_social_link_step_up!, only: :create

  def show
    redirect_to(sign_app_settings_google_path(ri: params[:ri]))
  end

  def create
    params[:provider] = "google_app"
    continue
  end
end
