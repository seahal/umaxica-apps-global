# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::SessionRevocations::AllsController < ::Sign::Com::Settings::SessionsController
  def create = revoke_all
end
