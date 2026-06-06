# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::ResetAttemptsController < ::Sign::Com::Preference::ResetsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  def create = destroy
end
