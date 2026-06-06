# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::Challenge::PasskeysController < ::Sign::Org::In::Challenge::PasskeysController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/org/in/challenge/passkeys"] + super
end
