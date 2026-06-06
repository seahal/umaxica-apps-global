# typed: false
# frozen_string_literal: true

class Sign::App::Preference::ResetAttemptsController < ::Sign::App::Preference::ResetsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  def create = destroy
end
