# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# See preference_dual_write_contract_test.rb for why a real controller class is
# required rather than `Object.new.extend(...)`.
class PreferenceLogoutResetTestController < ::Base::App::ApplicationController
  include ::PreferenceCore
end

# Sign-out deliberately keeps the stored preference values -- it only records that
# the reset happened and drops the in-request state. This file pins that: the audit
# row is written, the values survive, and a failure while writing that row does not
# take the sign-out down with it.
class PreferenceLogoutResetAndParamsTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses

  def build_context(params = {})
    ctx = PreferenceLogoutResetTestController.new
    ctx.set_request!(ActionDispatch::TestRequest.create)
    ctx.define_singleton_method(:params) { ActionController::Parameters.new(params) }
    ctx.define_singleton_method(:preference_class) { AppPreference }
    ctx.define_singleton_method(:preference_prefix) { |_p = nil| "App" }
    ctx
  end

  test "delete_preference_cookie records the reset, keeps the values and clears request state" do
    preference = PreferenceLifecycleSurfaces.new_token_preference(:app, with_default_children: true)
    PreferenceLifecycleSurfaces.set_language!(preference, PreferenceLifecycleSurfaces::EN)
    ctx = build_context
    ctx.instance_variable_set(:@preferences, preference)

    audit_before = AppPreferenceChronicle.where(subject_id: preference.id.to_s).count

    assert_nil ctx.send(:delete_preference_cookie)

    assert_equal audit_before + 1, AppPreferenceChronicle.where(subject_id: preference.id.to_s).count,
                 "signing out must leave a reset record behind"
    assert_equal PreferenceLifecycleSurfaces::EN, preference.reload.app_preference_language.option_id,
                 "signing out must not discard the stored preference values"
    assert_nil ctx.instance_variable_get(:@preferences)
  end

  test "a failure while recording the reset does not break sign-out" do
    preference = PreferenceLifecycleSurfaces.new_token_preference(:app, with_default_children: true)
    ctx = build_context
    ctx.instance_variable_set(:@preferences, preference)
    ctx.define_singleton_method(:preference_audit_class) { raise ActiveRecord::StatementInvalid, "chronicle unavailable" }

    assert_nil ctx.send(:delete_preference_cookie)
    assert_nil ctx.instance_variable_get(:@preferences)
  end

  test "cookie and selectable params accept the unscoped form the web endpoint posts" do
    ctx = build_context(functional: "1", performant: "0", targetable: "1", consented: "1")

    cookie_params = ctx.send(:preference_cookie_params)

    assert_equal "1", cookie_params[:functional]
    assert_equal "0", cookie_params[:performant]

    scoped = build_context(preference_cookie: { functional: "0" })

    assert_equal "0", scoped.send(:preference_cookie_params)[:functional]

    unscoped_option = build_context(language: "2")

    assert_equal "2", unscoped_option.send(:selectable_preference_params, :language)[:option_id]

    scoped_option = build_context(preference_language: { option_id: "1" })

    assert_equal "1", scoped_option.send(:selectable_preference_params, :language)[:option_id]
  end
end
