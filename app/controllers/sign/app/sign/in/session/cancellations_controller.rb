# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::Session::CancellationsController < ::Sign::App::Sign::In::SessionsController
  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  def create = destroy
end
