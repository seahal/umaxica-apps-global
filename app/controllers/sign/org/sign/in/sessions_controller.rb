# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::SessionsController < ::Sign::Org::In::SessionsController
  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  def self.local_prefixes = ["sign/org/in/sessions"] + super
end
