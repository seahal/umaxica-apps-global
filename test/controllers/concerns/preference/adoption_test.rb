# typed: false
# frozen_string_literal: true

require "test_helper"

module Preference
  class AdoptionTest < ActiveSupport::TestCase
    fixtures :users, :user_statuses,
             :app_preferences, :app_preference_statuses,
             :app_preference_binding_methods, :app_preference_dbsc_statuses,
             :app_preference_language_options, :app_preference_timezone_options,
             :app_preference_region_options, :app_preference_colortheme_options,
             :user_preference_language_options, :user_preference_timezone_options,
             :user_preference_region_options, :user_preference_colortheme_options

    setup do
      @user = users(:none_user)
      @preference = app_preferences(:one)
      @new_preference = app_preferences(:two)
      @adoption = build_adoption_context(@preference)

      # Clean up any existing UserPreference for our test user
      PrincipalRecord.connected_to(role: :writing) do
        UserPreference.where(user_id: @user.id).delete_all
      end
    end

    # --- adoptable_preference_class? ---

    test "adoptable_preference_class? returns true for AppPreference" do
      assert @adoption.send(:adoptable_preference_class?)
    end

    test "adoptable_preference_class? returns false for ComPreference" do
      adoption = build_adoption_context(@preference, preference_class_name: "ComPreference")

      assert_not adoption.send(:adoptable_preference_class?)
    end

    # --- find_resource_preference ---

    test "find_resource_preference returns nil when no UserPreference exists" do
      result = @adoption.send(:find_resource_preference, @user)

      assert_nil result
    end

    test "find_resource_preference returns UserPreference when it exists" do
      user_pref = create_user_preference!(@user)

      # Reload to pick up association
      @user.reload
      result = @adoption.send(:find_resource_preference, @user)

      assert_equal user_pref, result
    end

    # --- find_or_create_resource_preference! ---

    test "find_or_create_resource_preference! creates UserPreference when none exists" do
      assert_difference "UserPreference.count", 1 do
        @adoption.send(:find_or_create_resource_preference!, @user)
      end
    end

    test "find_or_create_resource_preference! returns existing UserPreference" do
      user_pref = create_user_preference!(@user)
      @user.reload

      assert_no_difference "UserPreference.count" do
        result = @adoption.send(:find_or_create_resource_preference!, @user)

        assert_equal user_pref, result
      end
    end

    # --- copy_preference_values! ---

    test "copy_preference_values! copies child record option_ids from source to target" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)
      user_pref = create_user_preference!(@user)
      target_lang = user_pref.user_preference_language

      @adoption.send(:copy_preference_values!, @preference, user_pref, "User")

      target_lang.reload

      assert_equal UserPreferenceLanguageOption::EN, target_lang.option_id
    end

    test "copy_preference_values! does not raise when source has no child records" do
      user_pref = create_user_preference!(@user)

      assert_nothing_raised do
        @adoption.send(:copy_preference_values!, @preference, user_pref, "User")
      end
    end

    # --- adopt_preference_for! (integration) ---

    test "adopt_preference_for! creates UserPreference on first login" do
      assert_difference "UserPreference.count", 1 do
        @adoption.send(:adopt_preference_for!, @user)
      end
    end

    test "adopt_preference_for! syncs preferences on subsequent login" do
      create_child_record!(@preference, :language, AppPreferenceLanguageOption::EN)

      # Simulate first login and create UserPreference.
      user_pref = create_user_preference!(@user)
      @user.reload

      # Touch app preference to make it newer
      SettingRecord.connected_to(role: :writing) { @preference.touch }

      # Now adopt and sync AppPreference to UserPreference.
      adoption = build_adoption_context(@preference)
      adoption.send(:adopt_preference_for!, @user)

      user_pref.user_preference_language.reload

      assert_equal UserPreferenceLanguageOption::EN, user_pref.user_preference_language.option_id
    end

    test "adopt_preference_for! does not raise on error and logs event" do
      adoption = build_adoption_context(@preference)
      adoption.define_singleton_method(:adoptable_preference_class?) { raise StandardError, "boom" }

      recorded_events = []
      mock_record = ->(name, payload = {}) { recorded_events << { name: name, payload: payload } }

      Rails.event.stub(:record, mock_record) do
        assert_nothing_raised do
          adoption.send(:adopt_preference_for!, @user)
        end
      end

      assert_equal 1, recorded_events.size, "Expected adoption error event to be recorded"
      assert_equal "preference.adoption.error", recorded_events.first[:name]
      assert_equal "StandardError", recorded_events.first[:payload][:error]
    end

    test "adopt_preference_for! is no-op when resource is blank" do
      assert_no_difference "UserPreference.count" do
        @adoption.send(:adopt_preference_for!, nil)
      end
    end

    # --- adopt_rotated_preference! ---

    test "adopt_rotated_preference! syncs values to existing UserPreference" do
      user_pref = create_user_preference!(@user)
      @user.reload

      create_child_record!(@new_preference, :language, AppPreferenceLanguageOption::EN)

      @adoption.send(:adopt_rotated_preference!, @user, @new_preference)

      user_pref.user_preference_language.reload

      assert_equal UserPreferenceLanguageOption::EN, user_pref.user_preference_language.option_id
    end

    test "adopt_rotated_preference! does not raise on error and logs event" do
      adoption = build_adoption_context(@preference)
      adoption.define_singleton_method(:adoptable_preference_class?) { raise StandardError, "boom" }

      recorded_events = []
      mock_record = ->(name, payload = {}) { recorded_events << { name: name, payload: payload } }

      Rails.event.stub(:record, mock_record) do
        assert_nothing_raised do
          adoption.send(:adopt_rotated_preference!, @user, @new_preference)
        end
      end

      assert_equal 1, recorded_events.size, "Expected adoption rotation error event to be recorded"
      assert_equal "preference.adoption.rotation_error", recorded_events.first[:name]
      assert_equal "StandardError", recorded_events.first[:payload][:error]
    end

    test "adopt_rotated_preference! is no-op when resource is blank" do
      assert_no_difference "UserPreference.count" do
        @adoption.send(:adopt_rotated_preference!, nil, @new_preference)
      end
    end

    private

    PREFERENCE_CLASSES = {
      "AppPreference" => AppPreference,
      "ComPreference" => ComPreference,
      "OrgPreference" => OrgPreference,
    }.freeze

    def build_adoption_context(preference, preference_class_name: "AppPreference")
      pref_class = PREFERENCE_CLASSES.fetch(preference_class_name)
      ctx = Object.new
      ctx.extend(Preference::Adoption)

      ctx.define_singleton_method(:preference_class) { pref_class }
      ctx.define_singleton_method(:preference_prefix) { |_pref = nil| pref_class.name.gsub("Preference", "") }
      ctx.define_singleton_method(:preference_option_classes) do |prefix|
        {
          language: Preference::ClassRegistry.option_class(prefix, :language),
          timezone: Preference::ClassRegistry.option_class(prefix, :timezone),
          region: Preference::ClassRegistry.option_class(prefix, :region),
          colortheme: Preference::ClassRegistry.option_class(prefix, :colortheme),
        }
      end
      ctx.instance_variable_set(:@preferences, preference)

      # Stub issue_access_token_from as no-op (JWT issuance not under test)
      ctx.define_singleton_method(:issue_access_token_from) { |_pref| nil }

      ctx
    end

    def create_user_preference!(user)
      PrincipalRecord.connected_to(role: :writing) do
        pref = UserPreference.create!(user_id: user.id)
        UserPreferenceLanguage.create!(preference_id: pref.id, option_id: UserPreferenceLanguageOption::JA)
        UserPreferenceTimezone.create!(preference_id: pref.id, option_id: UserPreferenceTimezoneOption::ASIA_TOKYO)
        UserPreferenceRegion.create!(preference_id: pref.id, option_id: UserPreferenceRegionOption::JP)
        UserPreferenceColortheme.create!(preference_id: pref.id, option_id: UserPreferenceColorthemeOption::SYSTEM)
        pref.reload
        pref
      end
    end

    def create_child_record!(preference, type, option_id)
      klass = {
        language: AppPreferenceLanguage,
        timezone: AppPreferenceTimezone,
        region: AppPreferenceRegion,
        colortheme: AppPreferenceColortheme,
      }.fetch(type)
      SettingRecord.connected_to(role: :writing) do
        klass.create!(preference_id: preference.id, option_id: option_id)
      end
    end
  end
end
