# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::CheckCancellationsController < ::Sign::Org::In::CheckpointsController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  def create = destroy
end
