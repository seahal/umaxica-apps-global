# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::CheckCancellationsController < ::Sign::App::In::CheckpointsController
  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  def create = destroy
end
