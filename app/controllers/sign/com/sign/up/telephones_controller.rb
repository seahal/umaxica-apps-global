# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::Up::TelephonesController < ::Sign::Com::Up::TelephonesController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/com/up/telephones"] + super
end
