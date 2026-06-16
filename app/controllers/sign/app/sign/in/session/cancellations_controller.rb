# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::Session::CancellationsController < ::Sign::App::ApplicationController
  include ::SignSessionLimitCancellationEndpoint

  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  before_action :require_session_limit_cancellation_access!

  def create = cancel_session_limit_session

  private

  def session_limit_pending_actor_session_key = :pending_login_user_id

  def session_limit_actor_class = Client

  def session_limit_sign_in_path = sign_app_sign_in_path(ri: params[:ri])
end
