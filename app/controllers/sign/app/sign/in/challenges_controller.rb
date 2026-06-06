# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::ChallengesController < ::Sign::App::In::ChallengesController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/app/in/challenges"] + super
end
