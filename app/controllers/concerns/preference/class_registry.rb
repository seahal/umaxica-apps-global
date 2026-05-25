# typed: false
# frozen_string_literal: true

module Preference
  module ClassRegistry
    module_function

    CHILD_RECORD_TYPES = %i(
      language
      timezone
      region
      theme
      currency
      date_format
      time_format
      motion
      density
      items_per_page
    ).freeze

    TYPE_KEY_MAP = {
      :timezone => :timezone,
      :language => :language,
      :region => :region,
      :currency => :currency,
      :date_format => :date_format,
      :time_format => :time_format,
      :motion => :motion,
      :density => :density,
      :items_per_page => :items_per_page,
      :colortheme => :theme,
      :theme => :theme,
      "Timezone" => :timezone,
      "Language" => :language,
      "Region" => :region,
      "Currency" => :currency,
      "DateFormat" => :date_format,
      "TimeFormat" => :time_format,
      "Motion" => :motion,
      "Density" => :density,
      "ItemsPerPage" => :items_per_page,
      "Colortheme" => :theme,
      "Theme" => :theme,
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
          theme: AppPreferenceThemeOption,
          currency: AppPreferenceCurrencyOption,
          date_format: AppPreferenceDateFormatOption,
          time_format: AppPreferenceTimeFormatOption,
          motion: AppPreferenceMotionOption,
          density: AppPreferenceDensityOption,
          items_per_page: AppPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: AppPreferenceTimezone,
          language: AppPreferenceLanguage,
          region: AppPreferenceRegion,
          theme: AppPreferenceTheme,
          currency: AppPreferenceCurrency,
          date_format: AppPreferenceDateFormat,
          time_format: AppPreferenceTimeFormat,
          motion: AppPreferenceMotion,
          density: AppPreferenceDensity,
          items_per_page: AppPreferenceItemsPerPage,
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
          theme: ComPreferenceThemeOption,
          currency: ComPreferenceCurrencyOption,
          date_format: ComPreferenceDateFormatOption,
          time_format: ComPreferenceTimeFormatOption,
          motion: ComPreferenceMotionOption,
          density: ComPreferenceDensityOption,
          items_per_page: ComPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: ComPreferenceTimezone,
          language: ComPreferenceLanguage,
          region: ComPreferenceRegion,
          theme: ComPreferenceTheme,
          currency: ComPreferenceCurrency,
          date_format: ComPreferenceDateFormat,
          time_format: ComPreferenceTimeFormat,
          motion: ComPreferenceMotion,
          density: ComPreferenceDensity,
          items_per_page: ComPreferenceItemsPerPage,
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
          theme: OrgPreferenceThemeOption,
          currency: OrgPreferenceCurrencyOption,
          date_format: OrgPreferenceDateFormatOption,
          time_format: OrgPreferenceTimeFormatOption,
          motion: OrgPreferenceMotionOption,
          density: OrgPreferenceDensityOption,
          items_per_page: OrgPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: OrgPreferenceTimezone,
          language: OrgPreferenceLanguage,
          region: OrgPreferenceRegion,
          theme: OrgPreferenceTheme,
          currency: OrgPreferenceCurrency,
          date_format: OrgPreferenceDateFormat,
          time_format: OrgPreferenceTimeFormat,
          motion: OrgPreferenceMotion,
          density: OrgPreferenceDensity,
          items_per_page: OrgPreferenceItemsPerPage,
        }.freeze,
      }.freeze,
      "Client" => {
        preference: ClientPreference,
        option_classes: {
          timezone: ClientPreferenceTimezoneOption,
          language: ClientPreferenceLanguageOption,
          region: ClientPreferenceRegionOption,
          theme: ClientPreferenceThemeOption,
          currency: ClientPreferenceCurrencyOption,
          date_format: ClientPreferenceDateFormatOption,
          time_format: ClientPreferenceTimeFormatOption,
          motion: ClientPreferenceMotionOption,
          density: ClientPreferenceDensityOption,
          items_per_page: ClientPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: ClientPreferenceTimezone,
          language: ClientPreferenceLanguage,
          region: ClientPreferenceRegion,
          theme: ClientPreferenceTheme,
          currency: ClientPreferenceCurrency,
          date_format: ClientPreferenceDateFormat,
          time_format: ClientPreferenceTimeFormat,
          motion: ClientPreferenceMotion,
          density: ClientPreferenceDensity,
          items_per_page: ClientPreferenceItemsPerPage,
        }.freeze,
      }.freeze,
      "Operator" => {
        preference: OperatorPreference,
        option_classes: {
          timezone: OperatorPreferenceTimezoneOption,
          language: OperatorPreferenceLanguageOption,
          region: OperatorPreferenceRegionOption,
          theme: OperatorPreferenceThemeOption,
          currency: OperatorPreferenceCurrencyOption,
          date_format: OperatorPreferenceDateFormatOption,
          time_format: OperatorPreferenceTimeFormatOption,
          motion: OperatorPreferenceMotionOption,
          density: OperatorPreferenceDensityOption,
          items_per_page: OperatorPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: OperatorPreferenceTimezone,
          language: OperatorPreferenceLanguage,
          region: OperatorPreferenceRegion,
          theme: OperatorPreferenceTheme,
          currency: OperatorPreferenceCurrency,
          date_format: OperatorPreferenceDateFormat,
          time_format: OperatorPreferenceTimeFormat,
          motion: OperatorPreferenceMotion,
          density: OperatorPreferenceDensity,
          items_per_page: OperatorPreferenceItemsPerPage,
        }.freeze,
      }.freeze,
      "Visitor" => {
        preference: VisitorPreference,
        option_classes: {
          timezone: VisitorPreferenceTimezoneOption,
          language: VisitorPreferenceLanguageOption,
          region: VisitorPreferenceRegionOption,
          theme: VisitorPreferenceThemeOption,
          currency: VisitorPreferenceCurrencyOption,
          date_format: VisitorPreferenceDateFormatOption,
          time_format: VisitorPreferenceTimeFormatOption,
          motion: VisitorPreferenceMotionOption,
          density: VisitorPreferenceDensityOption,
          items_per_page: VisitorPreferenceItemsPerPageOption,
        }.freeze,
        record_classes: {
          timezone: VisitorPreferenceTimezone,
          language: VisitorPreferenceLanguage,
          region: VisitorPreferenceRegion,
          theme: VisitorPreferenceTheme,
          currency: VisitorPreferenceCurrency,
          date_format: VisitorPreferenceDateFormat,
          time_format: VisitorPreferenceTimeFormat,
          motion: VisitorPreferenceMotion,
          density: VisitorPreferenceDensity,
          items_per_page: VisitorPreferenceItemsPerPage,
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

    def default_option_id(prefix, type)
      option = option_class(prefix, type)
      case TYPE_KEY_MAP.fetch(type)
      when :timezone then option::ASIA_TOKYO
      when :language then option::JA
      when :region then option::JP
      when :theme then option::SYSTEM
      when :currency then option::JPY
      when :date_format then option::ISO
      when :time_format then option::HOUR_24
      when :motion, :density then option::STANDARD
      when :items_per_page then option::PER_20
      end
    end
  end
end
