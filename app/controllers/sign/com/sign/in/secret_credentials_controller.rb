# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::SecretCredentialsController < ::Sign::Com::In::SecretCredentialsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/com/in/secret_credentials"] + super
end
