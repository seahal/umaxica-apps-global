# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::SessionRevocations::AllsController < ::Sign::Org::Settings::SessionsController
  AUTHENTICATION_MODE = :private

  def create = revoke_all
end
