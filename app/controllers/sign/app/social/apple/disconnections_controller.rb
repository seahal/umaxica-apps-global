# typed: false
# frozen_string_literal: true

class Sign::App::Social::Apple::DisconnectionsController < ::Sign::App::ApplicationController
  include CloudflareTurnstile
  include ::VerificationClient
  include SocialAuth
  include ::SignSocialAuthenticationEndpoint

  AUTHENTICATION_MODE = :private

  declare_authentication_mode! :private
  rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique
  before_action :authorize_social_unlink!, only: :create

  def create
    disconnect_social_authentication(provider: social_provider)
  end

  private

  def social_provider = "apple"
end
