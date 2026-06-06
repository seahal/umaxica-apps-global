# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::SessionRevocations::AllsController < ::Sign::Org::Settings::SessionsController
  def create = revoke_all
end
