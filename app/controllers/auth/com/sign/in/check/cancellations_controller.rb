# typed: false
# frozen_string_literal: true

class Auth::Com::Sign::In::Check::CancellationsController < ::Auth::Com::ApplicationController
  include SignComInCheckControllerSupport

  AUTHENTICATION_MODE = :private
  declare_authentication_mode! :private

  before_action :authenticate_visitor!
  before_action :continue_checkpoint_sequence_without_content!
  before_action :guard_timeout, only: %i(show update)

  def show = super

  def create = destroy

  def update = super
end
