# typed: false
# frozen_string_literal: true

class Sign::App::Social::Apple::ConnectionsController < ::Sign::App::Social::AuthenticationsController
  AUTHENTICATION_MODE = :open

  declare_authentication_mode! :open
  declare_authentication_mode! :private, only: :show

  before_action :authenticate_client!, only: :show
  before_action :require_social_link_step_up!, only: :create

  def show
    redirect_to(sign_app_settings_apple_path(ri: params[:ri]))
  end

  def create
    params[:provider] = "apple"
    continue
  end
end
