# typed: false
# frozen_string_literal: true

require "test_helper"

# A real controller class that `include`s PreferenceBase is required for the
# find_refresh_preference/load_preference_record_from_refresh_token! test
# below (not `Object.new.extend(PreferenceBase)`): ActiveSupport::Concern
# only flushes a module's nested `include` dependencies
# (PreferenceRefreshTokenTransport, etc.) when the concern is `include`d
# into a real class via `append_features`, which plain `Module#extend` on a
# bare instance never triggers.
class PreferenceDbscRetirementTestController < ::ApplicationController
  include ::PreferenceBase
end

# Traces the DBSC (Device Bound Session Credentials) binding verification
# path for the same class of bug found and fixed in
# preference_access_token_transport_test.rb (an unscoped `find_by` that
# ignored discarded_at/used_at, so a still-unexpired access JWT kept
# resolving to a retired preference row for up to 7 days).
#
# Trace result (see path evidence per method below): DBSC binding
# verification does NOT have that bug. Both the DBSC registration and the
# DBSC "bound cookie refresh" endpoints resolve their preference record via
# `PreferenceDbscRegistrationEndpoint#current_preference_record`
# (app/controllers/concerns/preference_dbsc_registration_endpoint.rb:23-26),
# which calls `load_preference_record_from_refresh_token!`
# (app/controllers/concerns/preference_refresh_token_transport.rb:11-46).
# That method's `find_refresh_preference` does use a bare `find_by`
# (preference_refresh_token_transport.rb:71-77) exactly like the access-JWT
# bug did, but its *caller* gates the result through `valid_refresh_preference?`
# (preference_refresh_token_transport.rb:21-24), which already checks
# `expires_at` (alias for discarded_at, app_preference.rb `alias_attribute
# :expires_at, :discarded_at`) and `!replay?` (used_at present) and
# `!revoked?` (preference_base.rb:870-876) before the record is ever
# returned as usable. `PreferenceSignOutRotation#retire_preference_after_sign_out!`
# sets exactly `used_at` and `discarded_at` to now, so a retired row fails
# `valid_refresh_preference?` unconditionally, regardless of what its own
# `dbsc_status_id`/`dbsc_session_id` still say. There is no separate DBSC
# lookup path that bypasses this gate. This test proves that end to end
# against a real DB row instead of trusting the trace alone.
class PreferenceDbscRetirementTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  setup do
    @preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "bound-session-id",
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
    )
    @ctx = Object.new
    @ctx.extend(PreferenceBase)
    @ctx.define_singleton_method(:preference_class) { AppPreference }
  end

  test "a DBSC-bound preference is valid before sign-out retirement (sanity check)" do
    assert @ctx.send(:valid_refresh_preference?, @preference)
  end

  test "a DBSC-bound preference retired by PreferenceSignOutRotation is rejected by valid_refresh_preference?" do
    @preference.update!(used_at: Time.current, discarded_at: Time.current)

    assert_not @ctx.send(:valid_refresh_preference?, @preference),
               "a retired preference row must fail the refresh/DBSC validity gate regardless of its own dbsc_status_id"
  end

  test "retirement rejects the row even though dbsc_status_id/dbsc_session_id are left untouched" do
    @preference.update!(used_at: Time.current, discarded_at: Time.current)
    @preference.reload

    # PreferenceSignOutRotation deliberately does not touch DBSC-specific
    # columns -- confirms the rejection above comes from the generic
    # discarded/used gate, not from any DBSC-specific field having been
    # cleared as a side effect.
    assert_equal AppPreferenceDbscStatus::ACTIVE, @preference.dbsc_status_id
    assert_equal "bound-session-id", @preference.dbsc_session_id
    assert_not @ctx.send(:valid_refresh_preference?, @preference)
  end

  test "load_preference_record_from_refresh_token! resolves nil for a retired DBSC-bound row presented with a valid digest" do
    # Mirrors the stubbing style of the pre-existing
    # "load preference record from refresh token covers valid invalid and
    # create branches" test in test/controllers/concerns/preference/base_test.rb:1334
    # -- stub the token-parsing boundary and exercise the real DB-backed
    # find_refresh_preference/valid_refresh_preference? gate.
    digest = "fixed-digest-for-test"
    @preference.update!(token_digest: digest, used_at: Time.current, discarded_at: Time.current)

    ctx = PreferenceDbscRetirementTestController.new
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_associations_to_preload) { [] }
    ctx.define_singleton_method(:with_preference_connection) { |_role, &blk| blk.call }
    ctx.define_singleton_method(:secure_compare?) { |a, b| a == b }
    ctx.define_singleton_method(:preference_refresh_binding_allowed?) { |_pref| true }
    ctx.define_singleton_method(:refresh_token_value) { "irrelevant-raw-token" }
    public_id = @preference.public_id
    ctx.define_singleton_method(:refresh_token_data) { |_token| [public_id, digest] }
    ctx.define_singleton_method(:handle_preference_refresh_failed) { |*_args| nil }
    ctx.define_singleton_method(:handle_preference_refresh_replay!) { |*_args| nil }

    preference, created = ctx.send(:load_preference_record_from_refresh_token!, create_if_missing: false)

    assert_nil preference
    assert_not created
  end
end
