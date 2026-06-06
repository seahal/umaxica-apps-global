# typed: false
# frozen_string_literal: true

class Sign::App::Social::Google::ConnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  def create
    params[:provider] = "google_app"
    continue
  end
end
