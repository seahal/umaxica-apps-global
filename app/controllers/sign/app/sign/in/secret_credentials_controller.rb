# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::SecretCredentialsController < ::Sign::App::In::SecretCredentialsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/app/in/secret_credentials"] + super
end
