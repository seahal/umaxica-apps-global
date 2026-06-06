# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::ChallengesController < ::Sign::Org::In::ChallengesController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/org/in/challenges"] + super
end
