# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::SecretCredentialsController < ::Sign::Org::In::SecretCredentialsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/org/in/secret_credentials"] + super
end
