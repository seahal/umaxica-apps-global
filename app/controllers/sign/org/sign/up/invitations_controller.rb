# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::Up::InvitationsController < ::Sign::Org::Up::InvitationsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest

  def self.local_prefixes = ["sign/org/up/invitations"] + super
end
