# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::SessionCancellationsController < ::Sign::Org::In::SessionsController
  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  def create = destroy
end
