# typed: false
# frozen_string_literal: true

# Manages session (refresh token) limits for Org staff.
#
# When a staff member exceeds their maximum concurrent sessions during login,
# they are logged in with a "restricted" session that only allows session management.
# This controller handles:
#   - show: Display active and restricted sessions
#   - update: Promote restricted session to active (after revoking an active session)
#   - destroy: Cancel the restricted session (logout) or revoke a specific session
#
# Routes:
#   GET    /in/session  -> #show
#   PATCH  /in/session  -> #update
#   DELETE /in/session  -> #destroy
#
# The restricted session approach avoids blocking login while ensuring staff
# can manage their sessions. Invariant: max 1 restricted session per staff.
class Sign::Org::In::SessionsController < Sign::Org::ApplicationController
  include SessionLimitGate

  # This controller handles session management for both authenticated staff
  # and staff who are in the process of logging in (with a pending gate).
  # Override the default guest_only! policy to allow access.
  public_strict!

  # For show/update/destroy, staff must be logged in (even if restricted)
  before_action :require_authentication_or_gate

  # Display active and restricted sessions for the staff
  def show
    load_session_data
  end

  # Revoke selected sessions and optionally promote restricted to active
  def update
    @current_operator = resolve_current_operator
    return redirect_to_login unless @current_operator

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_operator, ref)
    else
      # Revoke selected sessions by signed references
      refs = Array(params[:revoke_refs]).compact_blank
      if refs.empty?
        flash[:alert] = I18n.t("session_limit.no_sessions_selected")
        load_session_data
        return render :show, status: :unprocessable_content
      end

      revoke_sessions_by_refs(@current_operator, refs)
    end

    # Check if we can promote restricted session to active
    if current_session_restricted? && can_promote_session?(@current_operator)
      promote_current_session!
      consume_session_limit_gate!
      session.delete(:pending_login_staff_id)
      return redirect_to_return_path(notice: I18n.t("session_limit.promoted"))
    end

    # Still restricted, stay on session management
    flash[:notice] = I18n.t("session_limit.sessions_revoked")
    load_session_data
    render :show
  end

  # Cancel the restricted session (logout) or revoke a specific session
  def destroy
    @current_operator = resolve_current_operator
    return redirect_to_login unless @current_operator

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_operator, ref)
      load_session_data
      render :show
    else
      # Cancel: revoke current restricted session and logout
      if current_session&.restricted?
        current_session.revoke!
      end
      consume_session_limit_gate!
      session.delete(:pending_login_staff_id)
      log_out
      redirect_to(new_sign_org_in_path, notice: I18n.t("session_limit.cancelled"))
    end
  end

  private

  def require_authentication_or_gate
    return if current_session_restricted? || restricted_session_expired?

    # If logged in with a restricted session, allow access (this is the intended staff)
    # If logged in with an active (non-restricted) session, deny access.
    # This page is only for staff in the restricted session state (3rd login).
    if logged_in?
      head :forbidden
      return
    end

    # If not logged in but has a valid gate, try to load pending staff
    if session_limit_gate_valid? && session[:pending_login_staff_id].present?
      return
    end

    redirect_to_login
  end

  def redirect_to_login
    redirect_to(
      new_sign_org_in_path,
      alert: I18n.t("session_limit.login_required"),
    )
  end

  def redirect_to_return_path(notice:)
    return_path = retrieve_redirect_parameter || session_limit_return_to
    consume_session_limit_gate!

    if return_path.present?
      flash[:notice] = notice
      jump_to_generated_url(return_path, fallback: sign_org_configuration_path)
    else
      redirect_to(sign_org_configuration_path, notice: notice)
    end
  end

  def resolve_current_operator
    # Prefer current_resource (logged in staff)
    return current_resource if current_resource

    # Fall back to pending staff from gate
    staff_id = session[:pending_login_staff_id]
    Operator.find_by(id: staff_id) if staff_id
  end

  def load_session_data
    @current_operator = resolve_current_operator
    return unless @current_operator

    @active_sessions = @current_operator.staff_tokens.active_status.order(created_at: :desc)
    @restricted_sessions = @current_operator.staff_tokens.restricted_status.order(created_at: :desc)
    @current_session_public_id = current_session_public_id
  end

  def can_promote_session?(staff)
    # Can promote if active session count is below limit
    active_count =
      TokenRecord.connected_to(role: :writing) do
        OperatorToken.active_status.where(staff_id: staff.id).count
      end
    active_count < OperatorToken::MAX_SESSIONS_PER_STAFF
  end

  def promote_current_session!
    return unless current_session&.restricted?

    TokenRecord.connected_to(role: :writing) do
      current_session.promote_to_active!
    end
    @current_session = nil # Clear cached session
  end

  def revoke_session_by_ref(staff, ref)
    token = OperatorToken.find_from_signed_ref(ref)
    unless token && token.staff_id == staff.id
      flash[:alert] = I18n.t("session_limit.invalid_session")
      return
    end

    # Don't allow revoking the current session via ref (use destroy without ref for that)
    if token.public_id == current_session_public_id
      flash[:alert] = I18n.t("session_limit.cannot_revoke_current")
      return
    end

    TokenRecord.connected_to(role: :writing) do
      token.revoke!
    end

    flash[:notice] = I18n.t("session_limit.session_revoked")
  end

  def revoke_sessions_by_refs(staff, refs)
    revoked_count = 0

    TokenRecord.connected_to(role: :writing) do
      OperatorToken.transaction do
        OperatorToken.find_from_signed_refs(refs).each do |token|
          next unless token && token.staff_id == staff.id
          next if token.public_id == current_session_public_id # Skip current session

          token.revoke!
          revoked_count += 1
        end
      end
    end

    revoked_count
  end
end
