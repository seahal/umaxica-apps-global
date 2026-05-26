# typed: false
# frozen_string_literal: true

# Legacy compatibility gate for concurrent session-limit management.
#
# DB-backed sign-in cycles should use SignIn::SessionLimitManager as the
# authoritative session-limit participant. This concern remains only for
# sign-in entry points that have not yet been fully wired to DB-backed cycle
# locators.
#
# Provides server-side session gating for concurrent session limit management.
# When a user exceeds their maximum concurrent sessions, they are redirected to
# a session management screen where they can revoke existing sessions.
#
# The gate uses server-side session storage with a 15-minute TTL and a nonce
# to prevent replay attacks and ensure one-time use.
#
# Usage in controllers:
#   include SessionLimitGate
#
#   # In login flow (when session limit exceeded):
#   issue_session_limit_gate!(pt: request.fullpath, flow: "in.email.session")
#   redirect_to edit_sign_app_in_email_session_path
#
#   # In session management controller:
#   before_action :require_valid_gate
#
#   def edit
#     @active_sessions = current_user.client_tokens.active
#   end
#
#   def update
#     revoke_selected_sessions!
#     consume_session_limit_gate!
#     redirect_to session_limit_pt
#   end
module SessionLimitGate
  extend ActiveSupport::Concern
  include Common::Redirect

  GATE_SESSION_KEY = :session_limit_gate
  GATE_TTL_SECONDS = 900 # 15 minutes

  private

  # Issues a new session limit gate token.
  # This should be called when a user attempts to log in but exceeds their session limit.
  #
  # @param pt [String] The path target to use after session management (must start with "/")
  # @param flow [String] Identifier for the authentication flow (e.g., "in.email.session")
  def issue_session_limit_gate!(pt:, flow:)
    safe_pt = safe_internal_path(pt)

    session[GATE_SESSION_KEY] = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => Time.current.to_i,
      "pt" => safe_pt,
      "flow" => flow.to_s,
    }
  end

  def require_session_limit_gate!(login_path:)
    gate = session[GATE_SESSION_KEY]

    unless valid_gate?(gate)
      session.delete(GATE_SESSION_KEY)
      flash[:alert] = I18n.t("session_limit.gate_expired")
      redirect_to(login_path)
      return false
    end

    true
  end

  def consume_session_limit_gate!
    session.delete(GATE_SESSION_KEY)
  end

  def session_limit_pt
    gate = session[GATE_SESSION_KEY]
    return nil unless gate.is_a?(Hash)

    safe_internal_path(gate["pt"])
  end

  def session_limit_flow
    gate = session[GATE_SESSION_KEY]
    return nil unless gate.is_a?(Hash)

    gate["flow"]
  end

  def session_limit_gate_valid?
    valid_gate?(session[GATE_SESSION_KEY])
  end

  def session_limit_hard_reject_for?(resource)
    return false unless resource

    session_limit_state_for(resource) == :hard_reject
  end

  def render_session_limit_hard_reject(message: nil, http_status: nil)
    msg = message || I18n.t("session_limit.login_limit_exceeded")
    status = http_status || :forbidden

    respond_to do |format|
      format.html { render plain: msg, status: status }
      format.json { render json: { error: msg, error_code: "session_limit_hard_reject" }, status: status }
    end
  end

  def valid_gate?(gate)
    return false unless gate.is_a?(Hash)
    return false if gate["nonce"].blank?
    return false if gate["issued_at"].blank?

    issued_at = Integer(gate["issued_at"].to_s, 10)
    expires_at = issued_at + GATE_TTL_SECONDS

    Time.current.to_i < expires_at
  end
end
