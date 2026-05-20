# typed: false
# frozen_string_literal: true

module Authentication
  # Enforces the "current actor is in withdrawal lifecycle" gate: actors
  # in `closing` / `suspended` / `terminated` / `deactivated` states are
  # restricted to the configuration edit page and the withdrawal flow
  # itself. Anything else gets a redirect (HTML) or a 403 with
  # `WITHDRAWAL_REQUIRED` (JSON / non-HTML).
  #
  # Lives as its own concern (extracted from the very large
  # `Authentication::Base`) so the rule is reviewable in isolation and
  # to make it obvious where the allowlist gets edited.
  module WithdrawalGate
    extend ActiveSupport::Concern

    private

    def enforce_withdrawal_gate!
      return unless logged_in?
      return unless current_resource
      return unless withdrawal_restricted_resource?(current_resource)

      # Allowlist: configuration edit and withdrawal flow
      return if withdrawal_gate_allowlisted?

      # API/JSON: return 403 Forbidden
      if request.format.json? || !request.format.html?
        render json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden
        return
      end

      # HTML: redirect to configuration edit page
      safe_redirect_to(withdrawal_gate_redirect_path, fallback: "/configuration/edit", status: :found)
    end

    def withdrawal_gate_allowlisted?
      return true if controller_path.end_with?("configuration/withdrawals") && %w(show new edit update
                                                                                  create destroy).include?(action_name)
      return true if controller_path.end_with?("configurations") && %w(edit update).include?(action_name)

      # Allowlist: health/assets (rarely needed but safe)
      return true if controller_path == "rails/health"

      false
    end

    def withdrawal_restricted_resource?(resource)
      return true if resource.respond_to?(:closing?) && resource.closing?
      return true if resource.respond_to?(:suspended?) && resource.suspended?
      return true if resource.respond_to?(:terminated?) && resource.terminated?

      resource.respond_to?(:deactivated?) && resource.deactivated?
    end

    def withdrawal_gate_redirect_path
      if respond_to?(:edit_sign_app_configuration_path, true)
        edit_sign_app_configuration_path(ri: params[Auth::IoKeys::Params::RI])
      elsif respond_to?(:edit_sign_org_configuration_path, true)
        edit_sign_org_configuration_path(ri: params[Auth::IoKeys::Params::RI])
      else
        "/configuration/edit"
      end
    rescue StandardError => e
      Rails.event.error("auth.withdrawal_gate.path_resolution_failed", message: e.message, exception: e)
      "/configuration/edit"
    end
  end
end
