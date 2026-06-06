# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::Challenge::TotpsController < ::Sign::App::In::Challenge::TotpsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/app/in/challenge/totps"] + super
end
