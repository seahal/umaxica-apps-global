# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::CheckCancellationsController < ::Sign::Com::ApplicationController
  include SignComInCheckControllerSupport

  def create = destroy
end
