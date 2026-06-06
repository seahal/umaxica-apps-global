# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::CheckCancellationsController < ::Sign::Com::In::CheckpointsController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  def create = destroy
end
