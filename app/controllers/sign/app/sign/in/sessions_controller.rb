# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::SessionsController < ::Sign::App::In::SessionsController
  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  def self.local_prefixes = ["sign/app/in/sessions"] + super
end
