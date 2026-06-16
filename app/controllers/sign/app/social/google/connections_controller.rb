# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::ConnectionsController < ::Sign::App::ApplicationController
  include CloudflareTurnstile
  include ::VerificationClient
  include SocialAuth
  include ::SignSocialAuthenticationEndpoint

  AUTHENTICATION_MODE = :open

  declare_authentication_mode! :open
  declare_authentication_mode! :private, only: :show

  before_action :authenticate_client!, only: :show
  before_action :require_social_link_step_up!, only: :create

  def show
    redirect_to(sign_app_settings_google_path(ri: params[:ri]))
  end

  def create
    continue_social_authentication(provider: social_provider)
  end

  private

  def social_provider = "google_app"
end
