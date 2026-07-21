# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# Shared app/com/org contract for PreferenceSignOutRotation. One set of
# assertions (defined once as instance methods below), executed once per
# surface via PreferenceLifecycleSurfaces -- not three copy-pasted test
# files. Surface differences (which preference class, which status/binding/
# dbsc-status class) come entirely from the shared adapter in
# test/support/preference_lifecycle_surfaces.rb.
class PreferenceSignOutRotationContractTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses,
           :org_preference_statuses, :org_preference_binding_methods, :org_preference_dbsc_statuses,
           :com_preference_statuses, :com_preference_binding_methods, :com_preference_dbsc_statuses

  PreferenceLifecycleSurfaces::SURFACES.each_key do |surface|
    test "#{surface}: rotation creates a new guest identity, retires the old row, and copies safe values as non-explicit" do
      old_pref = PreferenceLifecycleSurfaces.new_token_preference(surface)
      PreferenceLifecycleSurfaces.set_language!(old_pref, PreferenceLifecycleSurfaces::EN)
      PreferenceLifecycleSurfaces.set_theme!(old_pref, PreferenceLifecycleSurfaces::DARK)

      ctx = build_rotation_context(surface, old_pref)

      new_pref = nil
      assert_difference "#{old_pref.class.name}.count", 1 do
        ctx.send(:rotate_preference_after_sign_out!)
        new_pref = ctx.instance_variable_get(:@preferences)
      end

      assert_not_equal old_pref.id, new_pref.id, "#{surface}: rotation must create a distinct row, not reuse the old one"
      assert_equal PreferenceLifecycleSurfaces::EN, new_pref.public_send(PreferenceLifecycleSurfaces.language_association(new_pref)).option_id
      assert_equal PreferenceLifecycleSurfaces::DARK, new_pref.public_send(PreferenceLifecycleSurfaces.theme_association(new_pref)).option_id
      assert_not new_pref.explicit_field?(:language), "#{surface}: safe-copied seed must not be marked explicit"
      assert_not new_pref.explicit_field?(:theme)

      old_pref.reload

      assert_predicate old_pref, :replay?, "#{surface}: old row must be consumed"
      assert_operator old_pref.discarded_at, :<=, Time.current, "#{surface}: old row must fall out of the active scope"
    end

    test "#{surface}: no principal identifier appears anywhere on the new guest row" do
      old_pref = PreferenceLifecycleSurfaces.new_token_preference(surface)
      ctx = build_rotation_context(surface, old_pref)

      ctx.send(:rotate_preference_after_sign_out!)
      new_pref = ctx.instance_variable_get(:@preferences)

      # The token-scoped preference row has no FK/column for a principal
      # identifier at all (see the model's schema annotation), so this is a
      # structural guarantee: enumerate every column and confirm none of
      # them is a principal/resource identifier column.
      forbidden = %w(user_id staff_id visitor_id client_id operator_id account_id)

      assert_empty new_pref.attribute_names & forbidden,
                   "#{surface}: token-scoped preference row must never carry a principal identifier column"
    end

    test "#{surface}: rotation failure does not raise, is logged distinctly, and the old row stays untouched" do
      old_pref = PreferenceLifecycleSurfaces.new_token_preference(surface)
      ctx = build_rotation_context(surface, old_pref)
      ctx.define_singleton_method(:retire_preference_after_sign_out!) { |_pref| raise StandardError, "retire boom" }

      logged = []

      Rails.logger.stub(:error, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) do
        assert_nothing_raised { ctx.send(:rotate_preference_after_sign_out!) }
      end

      assert_equal 1, logged.size, "#{surface}: retirement failure must be logged as a distinct, observable event"
      assert_equal "preference.sign_out.retirement_failed", logged.first[:event]
      old_pref.reload

      assert_not old_pref.replay?, "#{surface}: old row must remain valid when rotation rolls back"
    end

    test "#{surface}: auth logout completes even when the optional guest bootstrap fails entirely" do
      old_pref = PreferenceLifecycleSurfaces.new_token_preference(surface)
      ctx = build_rotation_context(surface, old_pref)
      ctx.define_singleton_method(:create_new_preference_record!) { |**_kwargs| raise StandardError, "guest bootstrap boom" }

      # rotate_preference_after_sign_out! itself must never raise -- this is
      # the exact call site AuthenticationLogoutable#logout_current_session!
      # makes inside its `ensure` block (authentication_logoutable.rb:38-44),
      # so a raise here would break ordinary sign-out.
      assert_nothing_raised { ctx.send(:rotate_preference_after_sign_out!) }
    end
  end

  private

  def build_rotation_context(surface, old_pref)
    cfg = PreferenceLifecycleSurfaces.config(surface)
    ctx = Object.new
    ctx.extend(PreferenceSignOutRotation)
    ctx.instance_variable_set(:@preferences, old_pref)
    ctx.define_singleton_method(:preference_class) { cfg[:preference_class].call }
    owner_class =
      case cfg[:preference_class].call.name
      when "AppPreference" then AppSettingRecord
      when "OrgPreference" then OrgSettingRecord
      when "ComPreference" then ComSettingRecord
      end
    ctx.define_singleton_method(:preference_connection_class) { |_record| owner_class }
    ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }
    ctx.define_singleton_method(:create_new_preference_record!) do |params_hash: nil|
      _ = params_hash
      PreferenceLifecycleSurfaces.new_token_preference(surface, with_default_children: true)
    end
    ctx
  end
end
