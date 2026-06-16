# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::DisconnectionsController < ::Sign::App::ApplicationController
  include CloudflareTurnstile
  include ::VerificationClient
  include SocialAuth
  include ::SignSocialAuthenticationEndpoint

  AUTHENTICATION_MODE = :private

  declare_authentication_mode! :private
  before_action :authorize_social_unlink!, only: :create

  def create
    disconnect_social_authentication(provider: social_provider)
  end

  private

  def social_provider = "google_app"
end
