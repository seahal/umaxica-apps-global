# typed: false
# frozen_string_literal: true

class Sign::App::Social::Apple::DisconnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  def create
    params[:provider] = "apple"
    destroy
  end
end
