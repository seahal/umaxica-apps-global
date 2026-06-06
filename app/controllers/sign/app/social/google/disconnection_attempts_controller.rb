# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::DisconnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  def create
    params[:provider] = "google_app"
    destroy
  end
end
