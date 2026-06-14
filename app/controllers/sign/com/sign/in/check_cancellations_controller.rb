# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::CheckCancellationsController < ::Sign::Com::ApplicationController
  include SignComInCheckControllerSupport

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_visitor!
  before_action :continue_checkpoint_sequence_without_content!
  before_action :guard_timeout, only: %i(show update)

  def self.local_prefixes
    ["sign/com/in/checkpoints"] + super
  end

  def show = super

  def create = destroy

  def update = super
end
