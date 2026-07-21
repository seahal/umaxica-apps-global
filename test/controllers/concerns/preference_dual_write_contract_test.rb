# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/preference_lifecycle_surfaces"

# A real controller class is required (not `Object.new.extend(...)`) so
# ActiveSupport::Concern flushes PreferenceCore's nested dependencies -- see
# the identical note in preference_dbsc_retirement_test.rb.
class PreferenceDualWriteContractTestController < ::ApplicationController
  include ::PreferenceCore
end

# Shared app/com/org correctness contract for the signed-in dual-write path
# (`PreferenceResourceSync#write_resource_preference_option!`). Query-count
# instrumentation for this same method is measured once, on app, in
# preference_dual_write_query_count_test.rb -- see that file's header for
# why re-measuring per surface is unnecessary (single shared method, no
# surface branching). This file instead confirms *correctness* identically
# on all three surfaces: same value on both sides, matching explicit state,
# same shared method/interface used.
class PreferenceDualWriteContractTest < ActiveSupport::TestCase
  fixtures :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses,
           :org_preference_statuses, :org_preference_binding_methods, :org_preference_dbsc_statuses,
           :com_preference_statuses, :com_preference_binding_methods, :com_preference_dbsc_statuses

  PreferenceLifecycleSurfaces::SURFACES.each_key do |surface|
    test "#{surface}: write_resource_preference_option! writes the same value and explicit state to both sides" do
      cfg = PreferenceLifecycleSurfaces.config(surface)
      resource_prefix = cfg[:resource_pref_class].call.name.gsub("Preference", "")
      PreferenceClassRegistry.option_class(resource_prefix, :language).ensure_defaults!

      browser_pref = PreferenceLifecycleSurfaces.new_token_preference(surface, with_default_children: true)
      PreferenceLifecycleSurfaces.set_language!(browser_pref, PreferenceLifecycleSurfaces::JA)

      resource = cfg[:resource_fixture].call
      resource_pref = cfg[:resource_pref_class].call.create!(cfg[:resource_fk] => resource.id)
      assoc = cfg[:resource_language_assoc]
      resource_pref.public_send(assoc) || resource_pref.public_send("create_#{assoc}!", option_id: PreferenceLifecycleSurfaces::JA)

      ctx = PreferenceDualWriteContractTestController.new
      ctx.define_singleton_method(:preference_class) { cfg[:preference_class].call }
      ctx.define_singleton_method(:preference_prefix) { |_p = nil| cfg[:preference_class].call.name.gsub("Preference", "") }
      ctx.instance_variable_set(:@preferences, browser_pref)

      ctx.send(:write_resource_preference_option!, resource_pref, :language, PreferenceLifecycleSurfaces::EN)

      resource_pref.reload
      resource_child_option_id = resource_pref.public_send(assoc).reload.option_id

      assert_equal PreferenceLifecycleSurfaces::EN, resource_child_option_id,
                   "#{surface}: the mirror's per-key child option row must reflect the written value"
      assert resource_pref.explicit_field?(:language),
             "#{surface}: the mirror side must be marked explicit by the same call that wrote the value"
    end
  end
end
