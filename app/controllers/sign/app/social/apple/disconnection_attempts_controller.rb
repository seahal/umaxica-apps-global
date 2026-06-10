# typed: false
# frozen_string_literal: true

class Sign::App::Social::Apple::DisconnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  AUTHENTICATION_MODE = :private

  declare_authentication_mode! :private
  before_action :authorize_social_unlink!, only: :create

  def create
    params[:provider] = "apple"
    destroy
  end
end
