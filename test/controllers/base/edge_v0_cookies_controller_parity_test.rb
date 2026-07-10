# typed: false
# frozen_string_literal: true

require "test_helper"

# Cross-surface regression guard: the edge/v0 cookie consent JSON endpoint is `AUTHENTICATION_MODE
# = :open` on every surface. `transparent_refresh_access_token` is defined (with a `json?` guard) on
# all three surface ApplicationControllers, so all three must explicitly skip it here too, or a
# non-JSON request against this JSON-only endpoint could trigger an access-token refresh side effect
# on org but not on app/com (see docs/architecture/preference-behavior-contract.md).
#
# `enforce_withdrawal_gate!` is intentionally NOT part of this parity check: it is only defined on
# Base::App/Com::ApplicationController (customer/account withdrawal), not on
# Base::Org::ApplicationController (staff/operator has no withdrawal concept).
class EdgeV0CookiesControllerParityTest < ActiveSupport::TestCase
  CONTROLLERS = {
    app: Base::App::Edge::V0::CookiesController,
    com: Base::Com::Edge::V0::CookiesController,
    org: Base::Org::Edge::V0::CookiesController,
  }.freeze

  REQUIRED_SKIPS = %i(transparent_refresh_access_token).freeze

  test "app/com/org edge/v0 cookies controllers skip the same withdrawal/refresh before_actions" do
    active_by_surface = CONTROLLERS.transform_values { |klass| active_before_action_names(klass) }

    REQUIRED_SKIPS.each do |callback_name|
      active_by_surface.each do |surface, active|
        assert_not_includes active, callback_name,
                            "#{surface} CookiesController must skip :#{callback_name} to match app/com/org parity"
      end
    end
  end

  private

  # `skip_before_action` removes the matching callback from the chain entirely (no `:if`/`:unless`
  # guard used anywhere in this codebase for these two callbacks), so an unconditional skip shows up
  # simply as the filter's absence from `_process_action_callbacks`.
  def active_before_action_names(controller_class)
    controller_class._process_action_callbacks
      .select { |callback| callback.kind == :before }
      .map(&:filter)
  end
end
