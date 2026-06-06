# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::ChallengesController < ::Sign::Com::In::ChallengesController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/com/in/challenges"] + super
end
