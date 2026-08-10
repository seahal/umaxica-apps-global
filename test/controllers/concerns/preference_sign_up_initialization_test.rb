# typed: false
# frozen_string_literal: true

require "test_helper"

# Sign-up does not have (and, per the target semantics established in
# memos/2026-07-21-preference-lifecycle-hardening-implementation.md section
# 1.4, does not need) a dedicated `initialize_preference_after_sign_up!`
# method: `AuthenticationBase#issue_login_tokens_within_lock`
# (app/controllers/concerns/authentication_base.rb:466-498) calls
# `adopt_preference_for!` identically for both sign-in and sign-up (the
# `bootstrap_actor` flag only affects the session-limit gate, not preference
# adoption) -- app/controllers/concerns/authentication_base.rb:498. This
# file proves the shared per-key path actually produces correct sign-up
# semantics on all three surfaces, since sign-up is exactly the case where
# `find_or_create_resource_preference!` creates a brand-new principal
# Preference row and `sync_preferences!` runs against it immediately
# afterward.
#
# LanguageOption::JA == 1 and ::EN == 2 for every token-scoped and
# principal-scoped preference model (app_preference_language_option.rb,
# org_preference_language_option.rb, com_preference_language_option.rb,
# client_preference_language_option.rb, operator_preference_language_option.rb,
# visitor_preference_language_option.rb all agree on these two ids), so a
# single JA/EN constant pair is used across all three surfaces below.
module Preference
  class SignUpInitializationTest < ActiveSupport::TestCase
    fixtures :clients, :client_statuses, :operators, :operator_statuses, :visitors, :visitor_statuses,
             :app_preferences, :app_preference_statuses, :app_preference_binding_methods, :app_preference_dbsc_statuses,
             :org_preferences, :org_preference_statuses, :org_preference_binding_methods, :org_preference_dbsc_statuses,
             :com_preferences, :com_preference_statuses, :com_preference_binding_methods, :com_preference_dbsc_statuses

    JA = 1
    EN = 2

    SURFACES = {
      app: {
        preference_class: -> { AppPreference },
        status_class: -> { AppPreferenceStatus },
        binding_class: -> { AppPreferenceBindingMethod },
        dbsc_class: -> { AppPreferenceDbscStatus },
        resource_fixture: -> { Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER) },
        resource_pref_class: -> { ClientPreference },
        resource_fk: :user_id,
        resource_language_assoc: "user_preference_language",
      },
      org: {
        preference_class: -> { OrgPreference },
        status_class: -> { OrgPreferenceStatus },
        binding_class: -> { OrgPreferenceBindingMethod },
        dbsc_class: -> { OrgPreferenceDbscStatus },
        resource_fixture: -> { Operator.create!(status_id: OperatorStatus::NOTHING) },
        resource_pref_class: -> { OperatorPreference },
        resource_fk: :staff_id,
        resource_language_assoc: "staff_preference_language",
      },
      com: {
        preference_class: -> { ComPreference },
        status_class: -> { ComPreferenceStatus },
        binding_class: -> { ComPreferenceBindingMethod },
        dbsc_class: -> { ComPreferenceDbscStatus },
        resource_fixture: -> { Visitor.create!(status_id: VisitorStatus::NOTHING) },
        resource_pref_class: -> { VisitorPreference },
        resource_fk: :visitor_id,
        resource_language_assoc: "visitor_preference_language",
      },
    }.freeze

    SURFACES.each_key do |surface|
      test "#{surface}: an explicit safe browser value is imported into the newly created principal row" do
        with_surface(surface) do |cfg, browser_pref, resource|
          mark_language_explicit!(browser_pref, EN)

          resource_pref = adopt!(browser_pref, resource, cfg)

          assert_equal EN, resource_language(resource_pref, cfg).option_id
          assert resource_pref.explicit_field?(:language),
                 "an explicitly-chosen browser value must be imported as explicit, not silently as a seed"
        end
      end

      test "#{surface}: a non-explicit browser-continuity seed is NOT imported into the newly created principal row" do
        with_surface(surface) do |cfg, browser_pref, resource|
          # Seed-only write (mirrors PreferenceSignOutRotation#seed_guest_preference_from_sign_out!):
          # the value changes but explicit_fields is never touched.
          set_language_value!(browser_pref, EN)

          assert_not browser_pref.explicit_field?(:language), "sanity: seed must not be marked explicit"

          resource_pref = adopt!(browser_pref, resource, cfg)

          assert_equal JA, resource_language(resource_pref, cfg).option_id,
                       "a non-explicit browser seed must not overwrite the new principal's default"
          assert_not resource_pref.explicit_field?(:language)
        end
      end

      test "#{surface}: the freshly-created default row does not win merely because its own timestamp is newer" do
        with_surface(surface) do |cfg, browser_pref, resource|
          mark_language_explicit!(browser_pref, EN)
          # The browser row is now clearly OLDER than the about-to-be-created
          # principal default row (which gets `Time.current` at creation,
          # i.e. strictly after this travel_to block).
          travel_to(2.days.ago) { browser_pref.touch }

          resource_pref = adopt!(browser_pref, resource, cfg)

          assert_equal EN, resource_language(resource_pref, cfg).option_id,
                       "explicit authority, not timestamp, must decide the winner even when the new default row is newer"
        end
      end

      test "#{surface}: a user-selected default value remains explicit and is imported" do
        with_surface(surface) do |cfg, browser_pref, resource|
          # The user explicitly picked JA -- which also happens to be the
          # eventual principal default. Explicitness must not be inferred
          # from "does this differ from the default."
          mark_language_explicit!(browser_pref, JA)

          resource_pref = adopt!(browser_pref, resource, cfg)

          assert resource_pref.explicit_field?(:language),
                 "an explicitly-chosen default value must still be imported as explicit"
        end
      end

      test "#{surface}: adult-content gate is not imported as a normal display preference" do
        with_surface(surface) do |cfg, browser_pref, resource|
          resource.update!(birthdate: "2012-02-29") if resource.respond_to?(:birthdate=)

          resource_pref = adopt!(browser_pref, resource, cfg)

          assert_equal "deny", resource_pref.reload.adult_content_gate,
                       "adult_content_gate is server/age-policy authority, never a normal imported preference"
        end
      end
    end

    private

    def with_surface(surface)
      cfg = SURFACES.fetch(surface)
      preference_class = cfg[:preference_class].call
      browser_pref = preference_class.create!(
        status_id: cfg[:status_class].call::NOTHING,
        binding_method_id: cfg[:binding_class].call::NOTHING,
        dbsc_status_id: cfg[:dbsc_class].call::NOTHING,
        discarded_at: 20.years.from_now,
        purged_at: 20.years.from_now,
      )
      resource = cfg[:resource_fixture].call
      cfg[:resource_pref_class].call.where(cfg[:resource_fk] => resource.id).delete_all

      yield(cfg, browser_pref, resource)
    end

    def adopt!(browser_pref, resource, cfg)
      ctx = Object.new
      ctx.extend(PreferenceAdoption)
      ctx.define_singleton_method(:preference_class) { browser_pref.class }
      ctx.define_singleton_method(:preference_prefix) { |_pref = nil| browser_pref.class.name.gsub("Preference", "") }
      ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }
      ctx.instance_variable_set(:@preferences, browser_pref)

      ctx.send(:adopt_preference_for!, resource)
      cfg[:resource_pref_class].call.find_by!(cfg[:resource_fk] => resource.id)
    end

    def mark_language_explicit!(browser_pref, option_id)
      set_language_value!(browser_pref, option_id)
      browser_pref.mark_field_explicit!(:language)
    end

    def set_language_value!(browser_pref, option_id)
      assoc = "#{browser_pref.class.name.underscore}_language"
      child = browser_pref.public_send(assoc) || browser_pref.public_send("create_#{assoc}!", option_id: option_id)
      child.update!(option_id: option_id)
    end

    def resource_language(resource_pref, cfg)
      resource_pref.reload.public_send(cfg[:resource_language_assoc])
    end
  end
end
