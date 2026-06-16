# typed: false
# frozen_string_literal: true

module SignSessionLimitCancellationEndpoint
  extend ActiveSupport::Concern

  private

  def require_session_limit_cancellation_access!
    return if current_session_restricted? || restricted_session_expired?
    return if pending_session_limit_cycle?
    return if session_limit_gate_valid? && session[session_limit_pending_actor_session_key].present?

    if logged_in?
      head :forbidden
    else
      redirect_to_session_limit_login
    end
  end

  def cancel_session_limit_session
    actor = resolve_session_limit_cancellation_actor
    return redirect_to_session_limit_login unless actor

    AuthenticationLogoutCurrentSession.call(
      resource: actor,
      token: current_session,
      reason: "session_limit_cancelled",
    ) if current_session&.restricted?
    current_db_sign_in_flow_for_sequence&.fail_sign_in! if pending_session_limit_cycle?
    consume_session_limit_gate!
    session.delete(session_limit_pending_actor_session_key)
    log_out
    redirect_to(session_limit_sign_in_path)
  end

  def pending_session_limit_cycle?
    current_db_sign_in_flow_for_sequence&.sign_in_session_limit_pending?
  end

  def resolve_session_limit_cancellation_actor
    current_resource || session_limit_actor_class.find_by(id: session[session_limit_pending_actor_session_key])
  end

  def redirect_to_session_limit_login
    redirect_to(session_limit_sign_in_path)
  end
end
