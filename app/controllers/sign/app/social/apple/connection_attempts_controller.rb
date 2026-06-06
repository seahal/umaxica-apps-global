# typed: false
# frozen_string_literal: true

class Sign::App::Social::Apple::ConnectionAttemptsController < ::Sign::App::Social::AuthenticationsController
  def create
    params[:provider] = "apple"
    continue
  end
end
