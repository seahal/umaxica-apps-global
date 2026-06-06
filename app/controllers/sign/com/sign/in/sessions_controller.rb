# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::SessionsController < ::Sign::Com::In::SessionsController
  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  def self.local_prefixes = ["sign/com/in/sessions"] + super
end
