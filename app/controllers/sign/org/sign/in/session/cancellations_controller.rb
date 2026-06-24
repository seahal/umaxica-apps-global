# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::Session::CancellationsController < ::Sign::Org::ApplicationController
  include ::SignSessionLimitCancellationEndpoint

  AUTHENTICATION_MODE = :deny_all
  declare_authentication_mode! :open

  before_action :require_session_limit_cancellation_access!

  def create = cancel_session_limit_session

  private

  def session_limit_pending_actor_session_key = :pending_login_staff_id

  def session_limit_actor_class = Operator

  def session_limit_sign_in_path
    challenge = session[:oidc_authorization_login_challenge]
    if challenge.present?
      sign_org_sign_in_path(ri: current_region_identifier, login_challenge: challenge)
    else
      sign_org_sign_in_path(ri: current_region_identifier)
    end
  end
end
