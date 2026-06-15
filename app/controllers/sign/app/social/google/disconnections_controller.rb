# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::DisconnectionsController < ::Sign::App::Social::AuthenticationsController
  AUTHENTICATION_MODE = :private

  declare_authentication_mode! :private
  before_action :authorize_social_unlink!, only: :create

  def create
    params[:provider] = "google_app"
    destroy
  end
end
