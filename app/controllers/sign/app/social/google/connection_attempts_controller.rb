# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::ConnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  AUTHENTICATION_MODE = :open

  declare_authentication_mode! :open
  before_action :require_social_link_step_up!, only: :create

  def create
    params[:provider] = "google_app"
    continue
  end
end
