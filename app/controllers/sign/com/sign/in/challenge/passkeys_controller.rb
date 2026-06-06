# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::Challenge::PasskeysController < ::Sign::Com::In::Challenge::PasskeysController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/com/in/challenge/passkeys"] + super
end
