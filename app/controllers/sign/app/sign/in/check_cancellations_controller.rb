# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::CheckCancellationsController < ::Sign::App::ApplicationController
  include SignAppInCheckControllerSupport

  def create = destroy
end
