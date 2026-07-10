# typed: false
# frozen_string_literal: true

# Enforces the "current actor is in withdrawal lifecycle" gate: actors
# in `closing` / `suspended` / `terminated` / `deactivated` states are
# restricted to the withdrawal flow itself. Anything else gets a redirect (HTML) or a 403 with
# `WITHDRAWAL_REQUIRED` (JSON / non-HTML).
#
# Lives as its own concern (extracted from the very large
# `AuthenticationBase`) so the rule is reviewable in isolation and
# to make it obvious where the allowlist gets edited.
module AuthenticationWithdrawalGate
  extend ActiveSupport::Concern

  private

  def enforce_withdrawal_gate!
    return unless logged_in?
    return unless current_resource
    return unless withdrawal_restricted_resource?(current_resource)

    # Allowlist: withdrawal flow
    return if withdrawal_gate_allowlisted?

    # API/JSON: return 403 Forbidden
    if request.format.json? || !request.format.html?
      render json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden
      return
    end

    # HTML: redirect to the withdrawal lifecycle surface
    safe_redirect_to(withdrawal_gate_redirect_path, fallback: acme_withdrawal_gate_redirect_path, status: :found)
  end

  def withdrawal_gate_allowlisted?
    return true if withdrawal_controller_allowlisted?

    # Allowlist: health/assets (rarely needed but safe)
    return true if controller_path == "rails/health"

    false
  end

  def withdrawal_controller_allowlisted?
    %w(
      base/app/identity/withdrawals
      base/com/identity/withdrawals
    ).include?(controller_path) && %w(show new edit update create destroy).include?(action_name)
  end

  def withdrawal_restricted_resource?(resource)
    return true if resource.respond_to?(:closing?) && resource.closing?
    return true if resource.respond_to?(:suspended?) && resource.suspended?
    return true if resource.respond_to?(:terminated?) && resource.terminated?

    resource.respond_to?(:deactivated?) && resource.deactivated?
  end

  def withdrawal_gate_redirect_path
    ri = params[AuthIoKeys::Params::RI]
    return edit_base_app_identity_withdrawal_path(ri: ri) if controller_path.start_with?("auth/app/")
    return edit_base_com_identity_withdrawal_path(ri: ri) if controller_path.start_with?("auth/com/")
    return base_org_identity_path(ri: ri) if controller_path.start_with?("auth/org/")
    return edit_base_app_identity_withdrawal_path(ri: ri) if controller_path.start_with?("base/app/")
    return edit_base_com_identity_withdrawal_path(ri: ri) if controller_path.start_with?("base/com/")

    acme_withdrawal_gate_redirect_path
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "auth.withdrawal_gate.path_resolution_failed", message: e.message,
                                                       exception: e,
      ),
    )
    acme_withdrawal_gate_redirect_path
  end

  def withdrawal_gate_api_redirect_path
    ri = params[AuthIoKeys::Params::RI]
    return base_app_identity_withdrawal_path(ri: ri) if controller_path.start_with?("auth/app/")
    return base_com_identity_withdrawal_path(ri: ri) if controller_path.start_with?("auth/com/")
    return base_org_identity_path(ri: ri) if controller_path.start_with?("auth/org/")
    return base_app_identity_withdrawal_path(ri: ri) if controller_path.start_with?("base/app/")
    return base_com_identity_withdrawal_path(ri: ri) if controller_path.start_with?("base/com/")

    base_app_identity_withdrawal_path(ri: ri)
  end

  def acme_withdrawal_gate_redirect_path
    edit_base_app_identity_withdrawal_path(ri: params[AuthIoKeys::Params::RI])
  end
end
