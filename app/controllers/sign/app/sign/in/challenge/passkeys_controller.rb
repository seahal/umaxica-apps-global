# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::Challenge::PasskeysController < ::Sign::App::In::Challenge::PasskeysController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/app/in/challenge/passkeys"] + super
end
