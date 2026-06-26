# typed: false
# frozen_string_literal: true

class Sign::App::Settings::RevocationsController < Sign::App::ApplicationController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  def create = head(:gone)
end
