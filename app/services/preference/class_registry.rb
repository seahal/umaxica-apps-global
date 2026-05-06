# typed: false
# frozen_string_literal: true

module Preference
  module ClassRegistry
    module_function

    TYPE_KEY_MAP = {
      :timezone => :timezone,
      :language => :language,
      :region => :region,
      :colortheme => :colortheme,
      "Timezone" => :timezone,
      "Language" => :language,
      "Region" => :region,
      "Colortheme" => :colortheme,
    }.freeze

    REGISTRY = {
      "App" => {
        preference: AppPreference,
        status: AppPreferenceStatus,
        cookie: AppPreferenceCookie,
        audit: AppPreferenceChronicle,
        audit_event: AppPreferenceChronicleEvent,
        audit_level: AppPreferenceChronicleLevel,
        option_classes: {
          timezone: AppPreferenceTimezoneOption,
          language: AppPreferenceLanguageOption,
          region: AppPreferenceRegionOption,
          colortheme: AppPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: AppPreferenceTimezone,
          language: AppPreferenceLanguage,
          region: AppPreferenceRegion,
          colortheme: AppPreferenceColortheme,
        }.freeze,
      }.freeze,
      "Com" => {
        preference: ComPreference,
        status: ComPreferenceStatus,
        cookie: ComPreferenceCookie,
        audit: ComPreferenceChronicle,
        audit_event: ComPreferenceChronicleEvent,
        audit_level: ComPreferenceChronicleLevel,
        option_classes: {
          timezone: ComPreferenceTimezoneOption,
          language: ComPreferenceLanguageOption,
          region: ComPreferenceRegionOption,
          colortheme: ComPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: ComPreferenceTimezone,
          language: ComPreferenceLanguage,
          region: ComPreferenceRegion,
          colortheme: ComPreferenceColortheme,
        }.freeze,
      }.freeze,
      "Org" => {
        preference: OrgPreference,
        status: OrgPreferenceStatus,
        cookie: OrgPreferenceCookie,
        audit: OrgPreferenceChronicle,
        audit_event: OrgPreferenceChronicleEvent,
        audit_level: OrgPreferenceChronicleLevel,
        option_classes: {
          timezone: OrgPreferenceTimezoneOption,
          language: OrgPreferenceLanguageOption,
          region: OrgPreferenceRegionOption,
          colortheme: OrgPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: OrgPreferenceTimezone,
          language: OrgPreferenceLanguage,
          region: OrgPreferenceRegion,
          colortheme: OrgPreferenceColortheme,
        }.freeze,
      }.freeze,
      "User" => {
        preference: UserPreference,
        option_classes: {
          timezone: UserPreferenceTimezoneOption,
          language: UserPreferenceLanguageOption,
          region: UserPreferenceRegionOption,
          colortheme: UserPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: UserPreferenceTimezone,
          language: UserPreferenceLanguage,
          region: UserPreferenceRegion,
          colortheme: UserPreferenceColortheme,
        }.freeze,
      }.freeze,
      "Staff" => {
        preference: StaffPreference,
        option_classes: {
          timezone: StaffPreferenceTimezoneOption,
          language: StaffPreferenceLanguageOption,
          region: StaffPreferenceRegionOption,
          colortheme: StaffPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: StaffPreferenceTimezone,
          language: StaffPreferenceLanguage,
          region: StaffPreferenceRegion,
          colortheme: StaffPreferenceColortheme,
        }.freeze,
      }.freeze,
      "Customer" => {
        preference: CustomerPreference,
        option_classes: {
          timezone: CustomerPreferenceTimezoneOption,
          language: CustomerPreferenceLanguageOption,
          region: CustomerPreferenceRegionOption,
          colortheme: CustomerPreferenceColorthemeOption,
        }.freeze,
        record_classes: {
          timezone: CustomerPreferenceTimezone,
          language: CustomerPreferenceLanguage,
          region: CustomerPreferenceRegion,
          colortheme: CustomerPreferenceColortheme,
        }.freeze,
      }.freeze,
    }.freeze

    def fetch(prefix)
      REGISTRY.fetch(prefix) do
        raise KeyError, "Unknown preference prefix: #{prefix.inspect}"
      end
    end

    def for_controller_path(controller_path)
      prefix = controller_path.to_s.split("/")[1]&.capitalize
      fetch(prefix)[:preference]
    end

    def prefix_from_preference_class(preference_class)
      preference_class.name.delete_suffix("Preference")
    end

    def status_class_for(preference_class)
      fetch(prefix_from_preference_class(preference_class))[:status]
    end

    def audit_class_for(preference_class)
      fetch(prefix_from_preference_class(preference_class))[:audit]
    end

    def audit_event_class_for(preference_class)
      fetch(prefix_from_preference_class(preference_class))[:audit_event]
    end

    def audit_level_class_for(preference_class)
      fetch(prefix_from_preference_class(preference_class))[:audit_level]
    end

    def cookie_class(prefix)
      fetch(prefix)[:cookie]
    end

    def option_class(prefix, type)
      fetch(prefix)[:option_classes].fetch(TYPE_KEY_MAP.fetch(type))
    end

    def record_class(prefix, type)
      fetch(prefix)[:record_classes].fetch(TYPE_KEY_MAP.fetch(type))
    end
  end
end
