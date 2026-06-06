# typed: false
# frozen_string_literal: true

class Sign::App::Settings::SessionRevocations::AllsController < ::Sign::App::Settings::SessionsController
  def create = revoke_all
end
