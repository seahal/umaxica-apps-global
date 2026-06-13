# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::CheckCancellationsController < ::Sign::App::ApplicationController
  include SignAppInCheckControllerSupport

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_client!
  before_action :continue_checkpoint_sequence_without_content!
  before_action :guard_timeout, only: %i(show update)

  def self.local_prefixes
    ["sign/app/in/checkpoints"] + super
  end

  def create = destroy
end
