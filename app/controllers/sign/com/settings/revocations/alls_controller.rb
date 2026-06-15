# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Revocations::AllsController < ::Sign::Com::Settings::SessionsController
  AUTHENTICATION_MODE = :private

  def create = revoke_all
end
