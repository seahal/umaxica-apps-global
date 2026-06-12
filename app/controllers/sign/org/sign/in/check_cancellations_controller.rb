# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::CheckCancellationsController < ::Sign::Org::ApplicationController
  include SignOrgInCheckControllerSupport

  def create = destroy
end
