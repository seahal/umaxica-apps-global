# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::Up::EmailsController < ::Sign::Com::Up::EmailsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/com/up/emails"] + super
end
