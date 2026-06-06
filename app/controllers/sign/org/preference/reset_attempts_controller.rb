# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::ResetAttemptsController < ::Sign::Org::Preference::ResetsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open

  def create = destroy
end
