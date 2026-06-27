# typed: false
# frozen_string_literal: true

class Auth::App::Settings::RevocationsController < Auth::App::ApplicationController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  def create = head(:gone)
end
