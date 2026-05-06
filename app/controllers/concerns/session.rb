# typed: false
# frozen_string_literal: true

# TODO: review flash boundary handling across subdomains.
# Prevent flash leakage across subdomains and surfaces by validating origin boundary on each request.
# Treat surface (app/com/org) and realm (www/sign/docs/help/news) as a logical session boundary key.
# Record the boundary at the moment a flash message is created to preserve its origin context safely.
# Compare current request boundary with stored origin boundary before allowing flash usage in controller.
# Discard or clear flash when boundary mismatch is detected to avoid unintended cross-context display.
# Ensure this validation runs early in before_action to guarantee deterministic behavior across requests.
# Do not rely on upstream controllers; enforce boundary rules locally within each request lifecycle.
# Optionally allow specific transitions (e.g. sign to www) via a strict and explicit allowlist policy.
# Avoid expanding scope beyond flash; do not reset full session or interfere with authentication state.
# Prefer explicit messaging mechanisms for cross-boundary communication instead of relying on flash.

module Session
  extend ActiveSupport::Concern

  def reset_flash
    nil
  end
end
